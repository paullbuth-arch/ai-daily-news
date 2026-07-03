const els = {
  nav: document.querySelector("#mainNav"),
  view: document.querySelector("#viewRoot"),
  title: document.querySelector("#pageTitle"),
  subtitle: document.querySelector("#pageSubtitle"),
  search: document.querySelector("#globalSearch"),
  refresh: document.querySelector("#refreshBtn"),
  banner: document.querySelector("#stateBanner"),
  stateTitle: document.querySelector("#stateTitle"),
  stateText: document.querySelector("#stateText"),
  sideMode: document.querySelector("#sideMode"),
  sideMeta: document.querySelector("#sideMeta"),
  syncLamp: document.querySelector("#syncLamp"),
  navStock: document.querySelector("#navStock"),
  navOrders: document.querySelector("#navOrders"),
  navTasks: document.querySelector("#navTasks"),
  drawer: document.querySelector("#detailDrawer"),
  drawerBackdrop: document.querySelector("#drawerBackdrop"),
  toast: document.querySelector("#toast"),
};

const routes = {
  overview: ["经营总览", "今日经营、库存风险与订单动作"],
  inventory: ["库存管理", "双端同步库存，电脑端做筛选、改价和排查"],
  orders: ["订单时间线", "按状态跟进发货、售后和利润"],
  analytics: ["经营分析", "利润、周转、渠道、供应商与客户复盘"],
  operations: ["运营工具", "采购报价、行情、维修、代理和文案样本"],
  sync: ["双端同步", "安卓 App 与 deepsell.wiki 的服务器数据状态"],
};

const state = {
  route: currentRoute(),
  data: emptyData(),
  derived: null,
  mode: "loading",
  query: "",
  inventoryStatus: "active",
  orderStatus: "all",
  quoteModel: "",
  quoteCost: "",
  saving: false,
};

const REQUEST_TIMEOUT_MS = 5200;
const moneyFmt = new Intl.NumberFormat("zh-CN", { maximumFractionDigits: 0 });
const dateTimeFmt = new Intl.DateTimeFormat("zh-CN", {
  month: "numeric",
  day: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});

function apiBase() {
  const localPreview =
    location.protocol === "file:" ||
    location.hostname === "localhost" ||
    location.hostname === "127.0.0.1" ||
    location.hostname === "";
  return localPreview ? "https://deepsell.wiki" : "";
}

function apiUrl(path) {
  return `${apiBase()}${path}`;
}

async function request(path, options = {}) {
  const controller = new AbortController();
  const timer = window.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(apiUrl(path), {
      method: options.method || "GET",
      headers: {
        Accept: "application/json",
        ...(options.body ? { "Content-Type": "application/json" } : {}),
      },
      body: options.body ? JSON.stringify(options.body) : undefined,
      cache: "no-store",
      signal: controller.signal,
    });
    const text = await response.text();
    let payload = {};
    try {
      payload = text ? JSON.parse(text) : {};
    } catch {
      payload = { error: text || `请求失败 ${response.status}` };
    }
    if (!response.ok || payload.error) {
      throw new Error(payload.error || `请求失败 ${response.status}`);
    }
    return payload;
  } catch (error) {
    if (error && error.name === "AbortError") throw new Error("接口超时");
    throw error;
  } finally {
    window.clearTimeout(timer);
  }
}

function parseData(raw) {
  if (raw && raw.data && typeof raw.data === "object" && !Array.isArray(raw.data)) {
    return raw.data;
  }
  return raw && typeof raw === "object" ? raw : {};
}

async function loadData() {
  setLoading(true);
  try {
    if (shouldUseLocalPreviewOnly()) {
      setData(loadPreviewData(), "preview");
      setStatus("preview", "本地预览数据", "线上部署后读取同域 /api/data；本地可加 ?live=1 测试真实接口。");
      return;
    }
    const payload = await request("/api/data");
    setData(parseData(payload), "online");
    const hasBusinessData =
      state.derived.devices.length ||
      state.derived.orders.length ||
      state.derived.repairs.length ||
      state.derived.purchaseOrders.length;
    setStatus(
      "ok",
      hasBusinessData ? "服务器同步正常" : "服务器已连接",
      hasBusinessData ? "已读取安卓 App 同步数据" : "等待 App 写入经营数据",
    );
  } catch (error) {
    if (canUsePreviewData()) {
      setData(loadPreviewData(), "preview");
      setStatus("preview", "本地预览数据", `线上会读取 deepsell.wiki /api/data；接口提示：${error.message}`);
    } else {
      setData(emptyData(), "error");
      setStatus("error", "服务器读取失败", `${error.message}。网页端不提供账号输入，需要后端代理同步凭据。`);
    }
  } finally {
    setLoading(false);
  }
}

function setData(data, mode) {
  state.data = normalizeData(data);
  state.mode = mode;
  state.derived = deriveBusiness(state.data);
  renderApp();
}

function setLoading(loading) {
  els.refresh.disabled = loading;
  els.refresh.setAttribute("aria-busy", loading ? "true" : "false");
  if (loading) {
    els.sideMode.textContent = "连接中";
    els.sideMeta.textContent = "读取服务器数据";
    els.syncLamp.className = "lamp";
  }
}

function setStatus(kind, title, text) {
  els.banner.className = `state-banner ${kind === "ok" ? "ok" : kind === "error" ? "error" : ""}`;
  els.stateTitle.textContent = title;
  els.stateText.textContent = text;
  els.sideMode.textContent = kind === "ok" ? "已同步" : kind === "error" ? "异常" : "本地预览";
  els.sideMeta.textContent = kind === "ok" ? "服务器数据" : kind === "error" ? "需要后端检查" : "样例数据";
  els.syncLamp.className = `lamp ${kind === "ok" ? "online" : kind === "error" ? "error" : ""}`;
}

function canUsePreviewData() {
  return (
    location.protocol === "file:" ||
    location.hostname === "localhost" ||
    location.hostname === "127.0.0.1" ||
    location.hostname === ""
  );
}

function shouldUseLocalPreviewOnly() {
  return canUsePreviewData() && !new URLSearchParams(location.search).has("live");
}

async function commitData(label) {
  state.saving = true;
  try {
    touchSyncMeta();
    state.derived = deriveBusiness(state.data);
    renderApp();
    if (state.mode === "preview") {
      localStorage.setItem("deepsell_preview_data", JSON.stringify(state.data));
      toast(`${label}已保存到本地预览`);
      return true;
    }
    await request("/api/data", { method: "POST", body: state.data });
    setStatus("ok", "服务器同步正常", `${label}已写入服务器数据`);
    toast(`${label}已同步`);
    return true;
  } catch (error) {
    setStatus("error", "保存失败", `${error.message}。请检查 deepsell.wiki 后端是否已代理账号凭据。`);
    toast(`保存失败：${error.message}`);
    return false;
  } finally {
    state.saving = false;
    renderApp();
  }
}

function touchSyncMeta() {
  const settings = state.data.settings || {};
  settings.syncMeta = {
    updatedAt: new Date().toISOString(),
    deviceId: settings.syncMeta?.deviceId || "web_dashboard",
    schemaVersion: state.data.schemaVersion || 1,
  };
  state.data.settings = settings;
}

function renderApp() {
  renderShell();
  closeDrawer(false);
  const render = {
    overview: renderOverview,
    inventory: renderInventory,
    orders: renderOrders,
    analytics: renderAnalytics,
    operations: renderOperations,
    sync: renderSync,
  }[state.route];
  (render || renderOverview)();
}

function renderShell() {
  const [title, subtitle] = routes[state.route] || routes.overview;
  els.title.textContent = title;
  els.subtitle.textContent = subtitle;
  els.nav.querySelectorAll("[data-route]").forEach((button) => {
    button.classList.toggle("active", button.dataset.route === state.route);
  });
  els.navStock.textContent = String(state.derived?.stock.length || 0);
  els.navOrders.textContent = String(state.derived?.activeOrders.length || 0);
  els.navTasks.textContent = String(state.derived?.tasks.length || 0);
}

function renderOverview() {
  const d = state.derived;
  els.view.innerHTML = `
    <section class="metric-grid">
      ${metricCard("今日 GMV", money(d.todayGmv), d.yesterdayGmv ? compareText(d.todayGmv, d.yesterdayGmv) : "今日", `${d.todayOrders.length} 笔订单`)}
      ${metricCard("今日毛利", money(d.todayProfit), d.todayProfit >= 0 ? "净利" : "亏损", `毛利率 ${percent(d.todayGmv ? d.todayProfit / d.todayGmv : 0)}`)}
      ${metricCard("库存资金", money(d.capital), `${d.stock.length} 台`, `${d.stale.length} 台超过 15 天`, d.stale.length ? "warning" : "")}
      ${metricCard("待处理", String(d.tasks.length), d.tasks.length ? "需要跟进" : "清爽", `${d.pendingOrders.length} 待发货 · ${d.afterSales.length} 售后`, d.tasks.length ? "danger" : "")}
    </section>

    <section class="dashboard-grid">
      <article class="panel">
        <header class="panel-head">
          <div>
            <h2>经营曲线</h2>
            <p>近 12 个月 GMV 与净利</p>
          </div>
          <div class="segmented" aria-label="趋势范围">
            <button class="active" type="button">月度</button>
            <button type="button" data-route="analytics">分析</button>
          </div>
        </header>
        <canvas id="trendChart" class="chart-lg" width="920" height="330" aria-label="经营趋势"></canvas>
      </article>

      <article class="panel">
        <header class="panel-head">
          <div>
            <h2>库存结构</h2>
            <p>在售、待定价、滞销与售后风险</p>
          </div>
          <button class="ghost-button" type="button" data-route="inventory">进入库存</button>
        </header>
        <div class="donut-layout">
          <div class="donut-wrap">
            <canvas id="stockDonut" width="260" height="260"></canvas>
            <div class="donut-center"><span>在售库存</span><strong>${d.stock.length}</strong></div>
          </div>
          <div class="legend-list">
            ${legendRow("健康在售", d.healthy.length, d.stock.length, "var(--accent)")}
            ${legendRow("滞销关注", d.stale.length, d.stock.length, "var(--amber)")}
            ${legendRow("待定价", d.unpriced.length, d.stock.length, "var(--blue)")}
            ${legendRow("售后订单", d.afterSales.length, d.activeOrders.length || 1, "var(--red)")}
          </div>
        </div>
      </article>
    </section>

    <section class="dashboard-grid secondary">
      <article class="panel">
        <header class="panel-head">
          <div>
            <h2>今日动作</h2>
            <p>由库存、订单、行情自动生成</p>
          </div>
          <button class="ghost-button" type="button" data-route="operations">运营</button>
        </header>
        <div class="task-list">
          ${d.tasks.length ? d.tasks.slice(0, 7).map(taskRow).join("") : emptyBlock("暂无硬风险", "可以继续补行情、整理文案或查看采购机会")}
        </div>
      </article>

      <article class="panel">
        <header class="panel-head">
          <div>
            <h2>经营拆解</h2>
            <p>利润、库龄、渠道和质检</p>
          </div>
          <button class="ghost-button" type="button" data-route="analytics">更多</button>
        </header>
        <div class="breakdown-list">
          ${breakdownItem("均利", "平均单台利润", money(d.avgProfit), [18, 20, 24, 21, 28, 26, 30, 34, 32])}
          ${breakdownItem("周转", "平均周转天数", `${d.avgTurnoverDays} 天`, [38, 32, 28, 26, 24, 23, 20, 19, 17])}
          ${breakdownItem("渠道", "销售渠道数量", `${d.channels.length} 个`, [12, 16, 18, 20, 22, 22, 24, 25, 28])}
          ${breakdownItem("质检", "通过率", percent(d.qcStats.passRate), [70, 76, 74, 80, 84, 88, 86, 90, 92])}
        </div>
      </article>
    </section>
  `;
  drawLineChart(document.querySelector("#trendChart"), d.monthlyTrend, {
    primary: "gmv",
    secondary: "profit",
    primaryLabel: "GMV",
    secondaryLabel: "净利",
  });
  drawDonut(document.querySelector("#stockDonut"), [
    { value: d.healthy.length, color: cssVar("--accent") },
    { value: d.stale.length, color: cssVar("--amber") },
    { value: d.unpriced.length, color: cssVar("--blue") },
    { value: d.afterSales.length, color: cssVar("--red") },
  ]);
  document.querySelectorAll(".mini-chart").forEach((canvas) => {
    drawMiniChart(canvas, String(canvas.dataset.values).split(",").map(Number));
  });
}

function renderInventory() {
  const d = state.derived;
  const devices = filteredDevices();
  els.view.innerHTML = `
    <section class="metric-grid">
      ${metricCard("在售库存", `${d.stock.length} 台`, "库存 + 在售", `成本占用 ${money(d.capital)}`)}
      ${metricCard("待定价", `${d.unpriced.length} 台`, d.unpriced.length ? "需补齐" : "已完成", "影响上架与采购判断", d.unpriced.length ? "warning" : "")}
      ${metricCard("滞销", `${d.stale.length} 台`, "超过 15 天", `滞销资金 ${money(sum(d.stale, (x) => n(x.purchaseCost)))}`, d.stale.length ? "danger" : "")}
      ${metricCard("预估毛利", money(d.estimatedStockProfit), `${d.pricedStock.length} 台已定价`, `均价 ${money(avg(d.pricedStock, (x) => n(x.sellPrice)))}`)}
    </section>

    <section class="table-panel">
      <div class="toolbar">
        <div class="chip-row" aria-label="库存状态筛选">
          ${statusChipButton("active", "在库/在售", state.inventoryStatus)}
          ${statusChipButton("listed", "在售", state.inventoryStatus)}
          ${statusChipButton("in_stock", "库存", state.inventoryStatus)}
          ${statusChipButton("unpriced", "待定价", state.inventoryStatus)}
          ${statusChipButton("stale", "滞销", state.inventoryStatus)}
          ${statusChipButton("sold", "已售", state.inventoryStatus)}
          ${statusChipButton("all", "全部", state.inventoryStatus)}
        </div>
        <div class="control-row">
          <button class="small-button" type="button" data-export="inventory">导出 CSV</button>
        </div>
      </div>
      <div class="data-table-wrap">
        <table class="data-table">
          <thead>
            <tr>
              <th>设备</th>
              <th>状态</th>
              <th>售价</th>
              <th>成本</th>
              <th>预估/净利</th>
              <th>库龄</th>
              <th>电池</th>
              <th>采购渠道</th>
            </tr>
          </thead>
          <tbody>
            ${devices.length ? devices.map(deviceRow).join("") : tableEmptyRow(8, "没有匹配库存")}
          </tbody>
        </table>
      </div>
    </section>
  `;
}

function renderOrders() {
  const d = state.derived;
  const orders = filteredOrders();
  const totalGmv = sum(orders, (order) => n(order.amount));
  const totalProfit = sum(orders, orderProfit);
  els.view.innerHTML = `
    <section class="metric-grid">
      ${metricCard("当前订单", `${orders.length} 单`, `${d.activeOrders.length} 单有效`, `全部订单 ${d.orders.length}`)}
      ${metricCard("成交额", money(totalGmv), "当前筛选", `客单价 ${money(avg(orders, (x) => n(x.amount)))}`)}
      ${metricCard("净利", money(totalProfit), percent(totalGmv ? totalProfit / totalGmv : 0), "扣除售后成本", totalProfit < 0 ? "danger" : "")}
      ${metricCard("待跟进", `${d.pendingOrders.length + d.afterSales.length} 单`, `${d.pendingOrders.length} 待发货`, `${d.afterSales.length} 售后`, d.pendingOrders.length + d.afterSales.length ? "warning" : "")}
    </section>

    <section class="table-panel">
      <div class="toolbar">
        <div class="chip-row" aria-label="订单状态筛选">
          ${orderChipButton("all", "全部", state.orderStatus)}
          ${orderChipButton("pending", "待发货", state.orderStatus)}
          ${orderChipButton("shipped", "已发货", state.orderStatus)}
          ${orderChipButton("done", "已完成", state.orderStatus)}
          ${orderChipButton("aftersale", "售后", state.orderStatus)}
          ${orderChipButton("cancelled", "作废", state.orderStatus)}
        </div>
        <button class="small-button" type="button" data-export="orders">导出 CSV</button>
      </div>
      <div class="data-table-wrap">
        <table class="data-table">
          <thead>
            <tr>
              <th>订单</th>
              <th>状态</th>
              <th>买家</th>
              <th>渠道</th>
              <th>成交额</th>
              <th>净利</th>
              <th>售后</th>
              <th>日期</th>
            </tr>
          </thead>
          <tbody>
            ${orders.length ? orders.map(orderRow).join("") : tableEmptyRow(8, "没有匹配订单")}
          </tbody>
        </table>
      </div>
    </section>
  `;
}

function renderAnalytics() {
  const d = state.derived;
  els.view.innerHTML = `
    <section class="metric-grid">
      ${metricCard("库存金额", money(d.capital), `${d.stock.length} 台`, `资金周转率 ${d.capitalTurnover.toFixed(2)}`)}
      ${metricCard("平均单台利润", money(d.avgProfit), d.avgProfit >= 35000 ? "达标" : "目标 350+", `已售 ${d.soldDevices.length} 台`, d.avgProfit < 35000 ? "warning" : "")}
      ${metricCard("平均周转", `${d.avgTurnoverDays} 天`, d.avgTurnoverDays <= 15 ? "达标" : "偏慢", "目标 ≤ 15 天", d.avgTurnoverDays > 15 ? "warning" : "")}
      ${metricCard("售后率", percent(d.afterSaleRate), `${d.afterSales.length} 单`, "有效订单口径", d.afterSaleRate > 0.12 ? "danger" : "")}
    </section>

    <section class="dashboard-grid">
      <article class="panel">
        <header class="panel-head">
          <div><h2>月度经营</h2><p>GMV、净利和订单数</p></div>
        </header>
        <canvas id="analyticsTrend" class="chart-lg" width="920" height="330"></canvas>
      </article>
      <article class="panel">
        <header class="panel-head">
          <div><h2>库存年龄</h2><p>库龄越长越占现金</p></div>
        </header>
        <div class="legend-list" style="padding-top:16px">
          ${Object.entries(d.ageDist).map(([label, value], index) => legendRow(label, value, d.stock.length || 1, ["var(--accent)", "var(--blue)", "var(--amber)", "var(--red)"][index])).join("")}
        </div>
        <canvas id="ageBars" class="mini-chart" style="height:120px;margin-top:14px" width="420" height="120"></canvas>
      </article>
    </section>

    <section class="panel-grid-2">
      ${rankingPanel("型号利润排行", "按已售设备净利", d.profitByModel, "model", "profit", "count")}
      ${rankingPanel("型号周转排行", "快到慢", d.turnoverByModel, "model", "avgDays", "count", "天")}
      ${rankingPanel("渠道 GMV", "订单成交渠道", d.channels, "channel", "gmv", "count")}
      ${rankingPanel("供应商利润", "采购渠道表现", d.suppliers, "channel", "profit", "count")}
    </section>

    <section class="table-panel">
      <header class="table-head">
        <div><h2>客户复购</h2><p>订单自动聚合</p></div>
      </header>
      <div class="data-table-wrap">
        <table class="data-table">
          <thead><tr><th>客户</th><th>订单数</th><th>成交额</th><th>渠道</th><th>最近成交</th></tr></thead>
          <tbody>
            ${d.customers.length ? d.customers.slice(0, 12).map(customerRow).join("") : tableEmptyRow(5, "暂无客户数据")}
          </tbody>
        </table>
      </div>
    </section>
  `;
  drawLineChart(document.querySelector("#analyticsTrend"), d.monthlyTrend, {
    primary: "gmv",
    secondary: "profit",
    primaryLabel: "GMV",
    secondaryLabel: "净利",
  });
  drawBars(document.querySelector("#ageBars"), Object.values(d.ageDist));
}

function renderOperations() {
  const d = state.derived;
  const models = modelOptions();
  if (!state.quoteModel && models.length) state.quoteModel = models[0];
  const plan = buildPurchasePlan(state.quoteModel, yuanToFen(state.quoteCost));
  els.view.innerHTML = `
    <section class="dashboard-grid">
      <article class="panel">
        <header class="panel-head">
          <div><h2>收货报价器</h2><p>按历史成交、库存、周转和今日行情判断</p></div>
        </header>
        <div class="control-row" style="margin-top:16px">
          <select id="quoteModel" class="select" aria-label="选择型号">
            ${models.map((model) => `<option value="${esc(model)}" ${model === state.quoteModel ? "selected" : ""}>${esc(model)}</option>`).join("")}
          </select>
          <input id="quoteCost" class="input" type="number" min="0" inputmode="decimal" placeholder="对方报价(元)" value="${esc(state.quoteCost)}" />
        </div>
        <div class="quote-result">
          ${plan ? purchasePlanHtml(plan) : emptyBlock("缺少历史数据", "先选择型号并输入报价")}
        </div>
      </article>

      <article class="panel">
        <header class="panel-head">
          <div><h2>市场行情</h2><p>settings.marketPrices 最新记录</p></div>
        </header>
        <div class="legend-list" style="padding-top:16px">
          ${d.marketPrices.length ? d.marketPrices.slice(0, 8).map((item) => compactRow(item.model, `${money(item.price)} · ${item.date}`, item.price ? "已记录" : "缺价格")).join("") : emptyBlock("暂无行情", "App 端录入后会同步到这里")}
        </div>
      </article>
    </section>

    <section class="panel-grid-3">
      <article class="panel">
        <header class="panel-head"><div><h2>维修工单</h2><p>${d.repairs.length} 条记录 · ${money(d.repairStats.totalCost)}</p></div></header>
        <div class="compact-list" style="padding-top:16px">
          ${d.repairs.length ? d.repairs.slice(0, 8).map((r) => compactRow(r.deviceName || r.deviceId, `${r.type} · ${money(r.cost)} · ${shortDate(r.createdAt)}`, r.status || "维修")).join("") : emptyBlock("暂无维修工单", "App 端新增后自动汇总成本")}
        </div>
      </article>
      <article class="panel">
        <header class="panel-head"><div><h2>代理</h2><p>${d.agents.length} 个分销代理</p></div></header>
        <div class="compact-list" style="padding-top:16px">
          ${d.agents.length ? d.agents.slice(0, 8).map((a) => compactRow(a.name, `${a.phone || "未填联系方式"} · 佣金 ${percent(n(a.commissionRate))}`, money(a.totalGmv))).join("") : emptyBlock("暂无代理", "私域分销数据会在这里汇总")}
        </div>
      </article>
      <article class="panel">
        <header class="panel-head"><div><h2>文案样本</h2><p>${d.copyExamples.length} 条成交文案经验</p></div></header>
        <div class="compact-list" style="padding-top:16px">
          ${d.copyExamples.length ? d.copyExamples.slice(0, 6).map((e) => compactRow(e.title || "未命名样本", `${e.model || "通用"} · ${e.condition || "未标成色"} · ${e.tags || "无标签"}`, `${n(e.score) || 4} 星`)).join("") : emptyBlock("暂无文案样本", "从已售设备导入后会显示")}
        </div>
      </article>
    </section>

    <section class="table-panel">
      <header class="table-head">
        <div><h2>补货建议</h2><p>按 30 天销量和当前库存估算</p></div>
      </header>
      <div class="data-table-wrap">
        <table class="data-table">
          <thead><tr><th>型号</th><th>当前库存</th><th>近30天销量</th><th>建议库存</th><th>建议补货</th><th>采购上限</th></tr></thead>
          <tbody>
            ${d.restock.length ? d.restock.slice(0, 12).map(restockRow).join("") : tableEmptyRow(6, "暂无补货建议")}
          </tbody>
        </table>
      </div>
    </section>
  `;
}

function renderSync() {
  const d = state.derived;
  const meta = syncMeta(state.data);
  const settings = state.data.settings || {};
  els.view.innerHTML = `
    <section class="metric-grid">
      ${metricCard("同步来源", state.mode === "online" ? "服务器" : state.mode === "preview" ? "本地预览" : "异常", "deepsell.wiki", "不显示账号配置")}
      ${metricCard("最后更新", meta.updatedAt ? relativeTime(toDate(meta.updatedAt)) : "未知", meta.updatedAt ? shortDate(meta.updatedAt) : "等待 App 写入", `设备 ${meta.deviceId || "未标记"}`)}
      ${metricCard("数据版本", String(state.data.schemaVersion || meta.schemaVersion || 1), "schemaVersion", "兼容 App 存储结构")}
      ${metricCard("数据量", `${d.devices.length + d.orders.length} 条`, `${d.devices.length} 设备`, `${d.orders.length} 订单`)}
    </section>
    <section class="panel-grid-2">
      <article class="panel">
        <header class="panel-head"><div><h2>同步内容</h2><p>服务器保存的业务集合</p></div></header>
        <div class="legend-list" style="padding-top:16px">
          ${compactRow("devices", `${d.devices.length} 台设备`, "库存")}
          ${compactRow("orders", `${d.orders.length} 单订单`, "销售")}
          ${compactRow("repairOrders", `${d.repairs.length} 条维修`, "翻新")}
          ${compactRow("purchaseOrders", `${d.purchaseOrders.length} 张采购单`, "采购")}
          ${compactRow("qcReports", `${d.qcReports.length} 份质检`, "质检")}
          ${compactRow("xianyuCopyExamples", `${d.copyExamples.length} 条样本`, "文案")}
        </div>
      </article>
      <article class="panel">
        <header class="panel-head"><div><h2>同步策略</h2><p>网页端使用后端代理，不暴露账号输入</p></div></header>
        <div class="legend-list" style="padding-top:16px">
          ${compactRow("App 写入", "安卓 App 后台同步上传完整业务数据", "上传")}
          ${compactRow("网页读取", "网页端从 /api/data 读取同一份数据", "读取")}
          ${compactRow("网页保存", "改价、上架和订单状态会写回 /api/data", state.mode === "online" ? "可用" : "预览")}
          ${compactRow("本地字段", "auth_token、webdavConfig 等本地字段不会在界面出现", "隐藏")}
        </div>
      </article>
    </section>
    <section class="table-panel">
      <header class="table-head"><div><h2>settings 摘要</h2><p>只显示非敏感经营字段</p></div></header>
      <div class="data-table-wrap">
        <table class="data-table">
          <thead><tr><th>字段</th><th>状态</th><th>说明</th></tr></thead>
          <tbody>
            <tr><td class="strong">syncMeta</td><td>${meta.updatedAt ? "存在" : "缺失"}</td><td>${esc(meta.updatedAt || "App 下一次同步后生成")}</td></tr>
            <tr><td class="strong">marketPrices</td><td>${Object.keys(settings.marketPrices || {}).length} 个型号</td><td>市场行情历史</td></tr>
            <tr><td class="strong">xianyuCopyRules</td><td>${settings.xianyuCopyRules ? "已设置" : "未设置"}</td><td>闲鱼文案规则</td></tr>
            <tr><td class="strong">aiPromptRules</td><td>${settings.aiPromptRules ? "已设置" : "未设置"}</td><td>AI 功能规则</td></tr>
          </tbody>
        </table>
      </div>
    </section>
  `;
}

function metricCard(label, value, delta, hint, tone = "") {
  return `
    <article class="metric-card ${tone}">
      <header><span>${esc(label)}</span><em class="delta">${esc(delta)}</em></header>
      <strong>${esc(value)}</strong>
      <p>${esc(hint)}</p>
    </article>
  `;
}

function legendRow(label, value, total, color) {
  return `
    <div class="legend-row">
      <i style="--swatch:${color}"></i>
      <div><strong>${esc(label)}</strong><span>${value} / ${total || 0}</span></div>
      <em>${percent(total ? value / total : 0)}</em>
    </div>
  `;
}

function taskRow(task) {
  return `
    <button class="task-row ${task.tone || ""}" type="button" data-route="${esc(task.route || "inventory")}">
      <i></i>
      <div><strong>${esc(task.title)}</strong><span>${esc(task.detail)}</span></div>
      <em>${esc(task.action)}</em>
    </button>
  `;
}

function compactRow(title, subtitle, meta) {
  return `
    <div class="compact-row">
      <i></i>
      <div><strong>${esc(title)}</strong><span>${esc(subtitle)}</span></div>
      <em>${esc(meta)}</em>
    </div>
  `;
}

function breakdownItem(icon, title, value, values) {
  return `
    <div class="breakdown-item">
      <div class="badge-icon">${esc(icon)}</div>
      <div><h3>${esc(title)}</h3><strong>${esc(value)}</strong></div>
      <canvas class="mini-chart" width="220" height="64" data-values="${values.join(",")}"></canvas>
    </div>
  `;
}

function statusChipButton(key, label, active) {
  return `<button type="button" class="${key === active ? "active" : ""}" data-inventory-status="${esc(key)}">${esc(label)}</button>`;
}

function orderChipButton(key, label, active) {
  return `<button type="button" class="${key === active ? "active" : ""}" data-order-status="${esc(key)}">${esc(label)}</button>`;
}

function deviceRow(device) {
  const risk = deviceRisk(device);
  const profit = device.status === "sold" ? deviceProfit(device) : expectedProfit(device);
  return `
    <tr data-device-id="${esc(device.id)}">
      <td>
        <div class="model-cell">
          <strong>${esc(deviceName(device))}</strong>
          <span>${esc([device.serial, device.network, device.condition].filter(Boolean).join(" · ") || "未填序列号")}</span>
        </div>
      </td>
      <td>${statusPill(risk.label, risk.tone)}</td>
      <td class="money">${n(device.sellPrice) > 0 ? money(device.sellPrice) : "待定价"}</td>
      <td>${money(device.purchaseCost)}</td>
      <td class="money ${profit < 0 ? "text-bad" : "text-good"}">${n(device.sellPrice) > 0 ? money(profit) : "待补价"}</td>
      <td>${stockDays(device)} 天</td>
      <td>${n(device.batteryHealth) || "--"}%</td>
      <td>${esc(device.purchaseChannel || "未知")}</td>
    </tr>
  `;
}

function orderRow(order) {
  const after = n(order.afterSaleCost);
  return `
    <tr data-order-id="${esc(order.id)}">
      <td>
        <div class="model-cell">
          <strong>${esc(order.deviceName || order.deviceId || "未命名订单")}</strong>
          <span>${esc(order.id)}</span>
        </div>
      </td>
      <td>${statusPill(orderStatusText(order.status), orderStatusTone(order.status))}</td>
      <td>${esc(order.buyer || "未知买家")}</td>
      <td>${esc(order.channel || "未知")}</td>
      <td class="money">${money(order.amount)}</td>
      <td class="money ${orderProfit(order) < 0 ? "text-bad" : "text-good"}">${money(orderProfit(order))}</td>
      <td>${after > 0 || order.status === "aftersale" ? statusPill(after ? money(after) : "处理中", "bad") : "无"}</td>
      <td>${esc(shortDate(order.createdAt))}</td>
    </tr>
  `;
}

function rankingPanel(title, subtitle, rows, labelKey, valueKey, countKey, suffix = "") {
  return `
    <article class="panel">
      <header class="panel-head"><div><h2>${esc(title)}</h2><p>${esc(subtitle)}</p></div></header>
      <div class="compact-list" style="padding-top:16px">
        ${
          rows.length
            ? rows.slice(0, 8).map((row, index) => {
                const raw = row[valueKey];
                const value = suffix ? `${raw}${suffix}` : money(raw);
                return `
                  <div class="compact-row">
                    <div class="rank-box">#${index + 1}</div>
                    <div><strong>${esc(row[labelKey])}</strong><span>${esc(row[countKey] || 0)} 台/单</span></div>
                    <em>${esc(value)}</em>
                  </div>
                `;
              }).join("")
            : emptyBlock("暂无数据", "App 端录入成交后生成排行")
        }
      </div>
    </article>
  `;
}

function customerRow(customer) {
  return `
    <tr>
      <td class="strong">${esc(customer.name)}</td>
      <td>${customer.count}</td>
      <td class="money">${money(customer.totalAmount)}</td>
      <td>${esc(customer.channels.join("、") || "未知")}</td>
      <td>${esc(shortDate(customer.lastDate))}</td>
    </tr>
  `;
}

function restockRow(item) {
  return `
    <tr>
      <td class="strong">${esc(item.model)}</td>
      <td>${item.inStock} 台</td>
      <td>${item.sales30d} 台</td>
      <td>${item.suggestedStock} 台</td>
      <td>${item.toPurchase > 0 ? statusPill(`补 ${item.toPurchase} 台`, "good") : statusPill("暂不补", "info")}</td>
      <td class="money">${item.maxPurchasePrice ? money(item.maxPurchasePrice) : "暂无"}</td>
    </tr>
  `;
}

function purchasePlanHtml(plan) {
  return `
    <div class="decision-card">
      <h3 class="${plan.tone === "bad" ? "text-bad" : plan.tone === "warn" ? "text-warn" : "text-good"}">${esc(plan.decision)}</h3>
      <p>${esc(plan.summary)}</p>
      <div class="fact-grid">
        ${fact("建议上限", money(plan.maxPurchase))}
        ${fact("预计净利", plan.avgSell ? money(plan.netProfit) : "暂无")}
        ${fact("保本售价", money(plan.breakEven))}
        ${fact("评分", `${plan.score} 分`)}
      </div>
    </div>
    <div class="legend-list">
      ${plan.risks.map((risk) => `<div class="risk-row ${risk.tone}"><i></i><div><strong>${esc(risk.title)}</strong><span>${esc(risk.text)}</span></div><em>${esc(risk.badge)}</em></div>`).join("")}
    </div>
  `;
}

function fact(label, value) {
  return `<div class="fact"><span>${esc(label)}</span><strong>${esc(value)}</strong></div>`;
}

function statusPill(text, tone = "") {
  const cls = tone === "good" ? "good" : tone === "warn" ? "warn" : tone === "bad" ? "bad" : tone === "info" ? "info" : "";
  return `<span class="status-pill ${cls}"><span class="status-dot"></span>${esc(text)}</span>`;
}

function tableEmptyRow(cols, text) {
  return `<tr><td colspan="${cols}"><div class="empty-state"><div><strong>${esc(text)}</strong><span>换个筛选或等待 App 同步数据</span></div></div></td></tr>`;
}

function emptyBlock(title, text) {
  return `<div class="empty-state"><div><strong>${esc(title)}</strong><span>${esc(text)}</span></div></div>`;
}

function showDeviceDrawer(id) {
  const device = state.derived.devices.find((item) => item.id === id);
  if (!device) return;
  const linkedOrders = state.derived.orders.filter((order) => order.deviceId === id);
  const linkedRepairs = state.derived.repairs.filter((repair) => repair.deviceId === id);
  const linkedQc = state.derived.qcReports.find((qc) => qc.deviceId === id);
  const risk = deviceRisk(device);
  els.drawer.innerHTML = `
    <div class="drawer-inner">
      <header class="drawer-head">
        <div>
          <h2>${esc(deviceName(device))}</h2>
          <p>${esc([device.serial, device.condition, device.network].filter(Boolean).join(" · ") || "设备详情")}</p>
        </div>
        <button class="icon-button" type="button" data-close-drawer aria-label="关闭">×</button>
      </header>
      <section class="drawer-section">
        <h3>经营状态</h3>
        <div class="kv-grid">
          ${kv("状态", risk.label)}
          ${kv("库龄", `${stockDays(device)} 天`)}
          ${kv("成本", money(device.purchaseCost))}
          ${kv(device.status === "sold" ? "净利" : "预估毛利", n(device.sellPrice) > 0 ? money(device.status === "sold" ? deviceProfit(device) : expectedProfit(device)) : "待定价")}
        </div>
        <div class="control-row">
          <input id="drawerPrice" class="input" type="number" min="0" inputmode="decimal" placeholder="售价(元)" value="${n(device.sellPrice) > 0 ? Math.round(n(device.sellPrice) / 100) : ""}" />
          <button class="small-button" type="button" data-save-price="${esc(device.id)}">保存价格</button>
        </div>
        <div class="drawer-actions">
          <button class="ghost-button" type="button" data-device-status="${esc(device.id)}:listed">标记在售</button>
          <button class="ghost-button" type="button" data-device-status="${esc(device.id)}:in_stock">标记库存</button>
        </div>
      </section>
      <section class="drawer-section">
        <h3>设备参数</h3>
        <div class="kv-grid">
          ${kv("容量", device.capacity || "--")}
          ${kv("颜色", device.color || "--")}
          ${kv("电池", `${n(device.batteryHealth) || "--"}% / ${n(device.cycleCount) || 0} 次`)}
          ${kv("ID 锁", device.idLockClean === false ? "需复核" : "干净")}
          ${kv("配件", device.accessories || "裸机")}
          ${kv("采购渠道", device.purchaseChannel || "未知")}
        </div>
      </section>
      <section class="drawer-section">
        <h3>关联记录</h3>
        <div class="compact-list">
          ${linkedOrders.length ? linkedOrders.map((order) => compactRow(order.deviceName || "订单", `${orderStatusText(order.status)} · ${order.buyer || "未知买家"}`, money(orderProfit(order)))).join("") : compactRow("暂无关联订单", "售出后会自动关联", "订单")}
          ${linkedRepairs.length ? linkedRepairs.map((repair) => compactRow(repair.type, `${repair.status || "维修"} · ${repair.note || "无备注"}`, money(repair.cost))).join("") : compactRow("暂无维修记录", "翻新维修会回写利润", "维修")}
          ${linkedQc ? compactRow("质检报告", `${linkedQc.grade || "未评级"} · ${linkedQc.conclusion || ""}`, linkedQc.allPassed ? "通过" : "复核") : compactRow("暂无质检报告", "App 端质检后同步", "质检")}
        </div>
      </section>
      ${
        device.description
          ? `<section class="drawer-section"><h3>商品描述</h3><p class="text-muted">${esc(device.description)}</p></section>`
          : ""
      }
    </div>
  `;
  openDrawer();
}

function showOrderDrawer(id) {
  const order = state.derived.orders.find((item) => item.id === id);
  if (!order) return;
  const device = state.derived.devices.find((item) => item.id === order.deviceId);
  els.drawer.innerHTML = `
    <div class="drawer-inner">
      <header class="drawer-head">
        <div>
          <h2>${esc(order.deviceName || "订单详情")}</h2>
          <p>${esc([order.buyer, order.channel, shortDate(order.createdAt)].filter(Boolean).join(" · "))}</p>
        </div>
        <button class="icon-button" type="button" data-close-drawer aria-label="关闭">×</button>
      </header>
      <section class="drawer-section">
        <h3>订单状态</h3>
        <div class="kv-grid">
          ${kv("状态", orderStatusText(order.status))}
          ${kv("成交额", money(order.amount))}
          ${kv("净利", money(orderProfit(order)))}
          ${kv("售后成本", n(order.afterSaleCost) > 0 ? money(order.afterSaleCost) : "无")}
        </div>
        <div class="drawer-actions">
          <button class="ghost-button" type="button" data-order-status-change="${esc(order.id)}:pending">待发货</button>
          <button class="ghost-button" type="button" data-order-status-change="${esc(order.id)}:shipped">已发货</button>
          <button class="ghost-button" type="button" data-order-status-change="${esc(order.id)}:done">已完成</button>
          <button class="ghost-button" type="button" data-order-status-change="${esc(order.id)}:aftersale">售后</button>
        </div>
      </section>
      <section class="drawer-section">
        <h3>买家与设备</h3>
        <div class="kv-grid">
          ${kv("买家", order.buyer || "未知")}
          ${kv("渠道", order.channel || "未知")}
          ${kv("订单 ID", order.id)}
          ${kv("设备 ID", order.deviceId)}
        </div>
      </section>
      ${
        device
          ? `<section class="drawer-section"><h3>关联库存</h3><div class="compact-list">${compactRow(deviceName(device), `${device.condition} · ${device.color} · ${device.serial || "无序列号"}`, money(device.purchaseCost))}</div></section>`
          : ""
      }
      ${
        order.afterSaleReason || order.afterSaleProgress || order.afterSaleResult
          ? `<section class="drawer-section"><h3>售后记录</h3><div class="kv-grid">${kv("原因", order.afterSaleReason || "--")}${kv("进度", order.afterSaleProgress || "--")}${kv("结果", order.afterSaleResult || "--")}</div></section>`
          : ""
      }
    </div>
  `;
  openDrawer();
}

function kv(label, value) {
  return `<div class="kv"><span>${esc(label)}</span><strong>${esc(value)}</strong></div>`;
}

function openDrawer() {
  els.drawer.hidden = false;
  els.drawerBackdrop.hidden = false;
}

function closeDrawer(render = true) {
  els.drawer.hidden = true;
  els.drawerBackdrop.hidden = true;
  els.drawer.innerHTML = "";
  if (render && state.derived) renderApp();
}

function filteredDevices() {
  const query = state.query.trim().toLowerCase();
  let devices = [...state.derived.devices];
  if (state.inventoryStatus === "active") {
    devices = devices.filter((d) => ["in_stock", "listed"].includes(String(d.status || "")));
  } else if (state.inventoryStatus === "listed") {
    devices = devices.filter((d) => d.status === "listed");
  } else if (state.inventoryStatus === "in_stock") {
    devices = devices.filter((d) => d.status === "in_stock");
  } else if (state.inventoryStatus === "unpriced") {
    devices = devices.filter((d) => ["in_stock", "listed"].includes(String(d.status || "")) && n(d.sellPrice) <= 0);
  } else if (state.inventoryStatus === "stale") {
    devices = devices.filter((d) => ["in_stock", "listed"].includes(String(d.status || "")) && stockDays(d) >= 15);
  } else if (state.inventoryStatus !== "all") {
    devices = devices.filter((d) => d.status === state.inventoryStatus);
  }
  if (query) {
    devices = devices.filter((d) =>
      [d.model, d.capacity, d.color, d.network, d.condition, d.serial, d.purchaseChannel, d.buyerContact]
        .join(" ")
        .toLowerCase()
        .includes(query),
    );
  }
  return devices.sort((a, b) => {
    const riskA = deviceRiskScore(a);
    const riskB = deviceRiskScore(b);
    if (riskA !== riskB) return riskB - riskA;
    return stockDays(b) - stockDays(a);
  });
}

function filteredOrders() {
  const query = state.query.trim().toLowerCase();
  let orders = [...state.derived.orders];
  if (state.orderStatus !== "all") {
    orders = orders.filter((order) => order.status === state.orderStatus);
  }
  if (query) {
    orders = orders.filter((order) =>
      [order.deviceName, order.buyer, order.channel, order.id, order.deviceId, order.createdAt]
        .join(" ")
        .toLowerCase()
        .includes(query),
    );
  }
  return orders.sort((a, b) => String(b.createdAt || "").localeCompare(String(a.createdAt || "")));
}

function deriveBusiness(data) {
  const devices = array(data.devices);
  const orders = array(data.orders);
  const agents = array(data.agents);
  const repairs = array(data.repairOrders);
  const repairParts = array(data.repairParts);
  const purchaseOrders = array(data.purchaseOrders);
  const qcReports = array(data.qcReports);
  const copyExamples = array(data.xianyuCopyExamples);
  const activeOrders = orders.filter((order) => order.status !== "cancelled");
  const today = dateKey();
  const yesterday = dateKey(-1);
  const stock = devices.filter((device) => ["in_stock", "listed"].includes(String(device.status || "")));
  const pricedStock = stock.filter((device) => n(device.sellPrice) > 0);
  const unpriced = stock.filter((device) => n(device.sellPrice) <= 0);
  const stale = stock.filter((device) => stockDays(device) >= 15);
  const healthy = stock.filter((device) => n(device.sellPrice) > 0 && stockDays(device) < 15);
  const soldDevices = devices.filter((device) => device.status === "sold");
  const todayOrders = activeOrders.filter((order) => startsWithDate(order.createdAt, today));
  const yesterdayOrders = activeOrders.filter((order) => startsWithDate(order.createdAt, yesterday));
  const pendingOrders = activeOrders.filter((order) => order.status === "pending");
  const shippedOrders = activeOrders.filter((order) => order.status === "shipped");
  const afterSales = activeOrders.filter((order) => order.status === "aftersale" || n(order.afterSaleCost) > 0);
  const todayGmv = sum(todayOrders, (order) => n(order.amount));
  const todayProfit = sum(todayOrders, orderProfit);
  const yesterdayGmv = sum(yesterdayOrders, (order) => n(order.amount));
  const capital = sum(stock, (device) => n(device.purchaseCost));
  const estimatedStockProfit = sum(pricedStock, expectedProfit);
  const monthlyTrend = monthlyStats(activeOrders);
  const dailyTrend = dailyStats(activeOrders);
  const channels = channelStats(activeOrders);
  const profitByModel = modelProfitStats(soldDevices);
  const turnoverByModel = modelTurnoverStats(soldDevices);
  const suppliers = supplierStats(soldDevices, activeOrders);
  const customers = customerStats(activeOrders);
  const ageDist = inventoryAgeDist(stock);
  const marketPrices = latestMarketPrices(data.settings?.marketPrices);
  const qcStats = qcReportStats(qcReports);
  const repairStats = repairOrderStats(repairs);
  const avgProfit = activeOrders.length ? Math.round(sum(activeOrders, orderProfit) / activeOrders.length) : 0;
  const avgTurnoverDays = averageTurnoverDays(soldDevices);
  const capitalTurnover = capital ? monthSales(activeOrders) / capital : 0;
  const afterSaleRate = activeOrders.length ? afterSales.length / activeOrders.length : 0;
  const restock = restockSuggestions(devices);
  const tasks = buildTasks({ unpriced, stale, pendingOrders, afterSales, marketPrices, stock, activeOrders });

  return {
    data,
    devices,
    orders,
    agents,
    repairs,
    repairParts,
    purchaseOrders,
    qcReports,
    copyExamples,
    activeOrders,
    stock,
    pricedStock,
    unpriced,
    stale,
    healthy,
    soldDevices,
    todayOrders,
    pendingOrders,
    shippedOrders,
    afterSales,
    todayGmv,
    todayProfit,
    yesterdayGmv,
    capital,
    estimatedStockProfit,
    monthlyTrend,
    dailyTrend,
    channels,
    profitByModel,
    turnoverByModel,
    suppliers,
    customers,
    ageDist,
    marketPrices,
    qcStats,
    repairStats,
    avgProfit,
    avgTurnoverDays,
    capitalTurnover,
    afterSaleRate,
    restock,
    tasks,
  };
}

function buildTasks(input) {
  const tasks = [];
  if (input.unpriced.length) {
    tasks.push({
      title: "补齐定价与描述",
      detail: `${input.unpriced.length} 台库存没有售价`,
      action: "去库存",
      route: "inventory",
      tone: "warning",
    });
  }
  if (input.stale.length) {
    tasks.push({
      title: "处理滞销库存",
      detail: `${input.stale.length} 台超过 15 天，资金 ${money(sum(input.stale, (x) => n(x.purchaseCost)))}`,
      action: "去库存",
      route: "inventory",
      tone: "danger",
    });
  }
  if (input.pendingOrders.length) {
    tasks.push({
      title: "核对待发货订单",
      detail: `${input.pendingOrders.length} 单等待物流与买家信息`,
      action: "去订单",
      route: "orders",
      tone: "warning",
    });
  }
  if (input.afterSales.length) {
    tasks.push({
      title: "跟进售后成本",
      detail: `${input.afterSales.length} 单影响净利`,
      action: "去订单",
      route: "orders",
      tone: "danger",
    });
  }
  if (!marketUpdatedToday(input.marketPrices)) {
    tasks.push({
      title: "补今日批发价",
      detail: "采购报价器会优先参考今日行情",
      action: "去运营",
      route: "operations",
      tone: "warning",
    });
  }
  const lowProfit = input.activeOrders.filter((order) => order.status !== "cancelled" && orderProfit(order) < 20000);
  if (lowProfit.length) {
    tasks.push({
      title: "复盘低毛利订单",
      detail: `${lowProfit.length} 单净利低于 ¥200`,
      action: "去分析",
      route: "analytics",
      tone: "warning",
    });
  }
  if (!tasks.length) {
    tasks.push({
      title: "今日没有硬风险",
      detail: `在售 ${input.stock.length} 台，订单 ${input.activeOrders.length} 单`,
      action: "看分析",
      route: "analytics",
    });
  }
  return tasks;
}

function normalizeData(data) {
  const normalized = {
    schemaVersion: n(data.schemaVersion) || 1,
    devices: array(data.devices),
    orders: array(data.orders),
    agents: array(data.agents),
    repairOrders: array(data.repairOrders),
    repairParts: array(data.repairParts),
    purchaseOrders: array(data.purchaseOrders),
    qcReports: array(data.qcReports),
    xianyuCopyExamples: array(data.xianyuCopyExamples),
    settings: data.settings && typeof data.settings === "object" && !Array.isArray(data.settings) ? { ...data.settings } : {},
  };
  return normalized;
}

function emptyData() {
  return normalizeData({ settings: { syncMeta: { schemaVersion: 1 } } });
}

function loadPreviewData() {
  const saved = localStorage.getItem("deepsell_preview_data");
  if (saved) {
    try {
      return normalizeData(JSON.parse(saved));
    } catch {
      localStorage.removeItem("deepsell_preview_data");
    }
  }
  return sampleData();
}

function sampleData() {
  const iso = (daysAgo, hour = 10, minute = 18) => {
    const d = new Date();
    d.setDate(d.getDate() - daysAgo);
    d.setHours(hour, minute, 0, 0);
    return d.toISOString();
  };
  const purchase = (daysAgo) => iso(daysAgo).slice(0, 10);
  const monthIso = (monthsAgo, day, hour) => {
    const d = new Date();
    d.setMonth(d.getMonth() - monthsAgo);
    d.setDate(day);
    d.setHours(hour, 10, 0, 0);
    return d.toISOString();
  };
  return normalizeData({
    schemaVersion: 1,
    settings: {
      syncMeta: {
        updatedAt: iso(0, new Date().getHours(), Math.max(0, new Date().getMinutes() - 4)),
        deviceId: "android-shop-main-01",
        schemaVersion: 1,
      },
      xianyuCopyRules: "少承诺，多讲真实成色、电池、适用场景和售后边界。",
      marketPrices: {
        "iPad Pro 11 2022": [
          { date: dateKey(-2), price: 382000 },
          { date: dateKey(), price: 388000 },
        ],
        "iPad Air 5": [{ date: dateKey(), price: 252000 }],
        "iPad mini 6": [{ date: dateKey(-1), price: 218000 }],
        "iPad 10": [{ date: dateKey(-4), price: 176000 }],
      },
    },
    devices: [
      device("d1", "iPad Pro 11 2022", "256G", "深空灰", "95新", 392000, 459900, "listed", 7, "闲鱼回收", "SN-PRO-2201", 91, 186),
      device("d2", "iPad Air 5", "64G", "蓝色", "99新", 258000, 318800, "listed", 2, "华强北档口", "SN-AIR-5012", 97, 74),
      device("d3", "iPad mini 6", "256G", "星光色", "9成新", 226000, 279900, "listed", 23, "个人回收", "SN-MINI-611", 88, 276),
      device("d4", "iPad 10", "64G", "银色", "95新", 188000, 0, "in_stock", 17, "抖音回收", "SN-IP10-889", 94, 102),
      device("d5", "iPad Pro 12.9 2021", "512G", "银色", "9成新", 468000, 529900, "listed", 31, "批发同行", "SN-129-2102", 86, 318),
      device("d6", "iPad Air 4", "256G", "绿色", "95新", 210000, 269900, "listed", 4, "线下门店", "SN-AIR-409", 92, 154),
      { ...device("d7", "iPad 9", "64G", "深空灰", "95新", 130000, 169900, "sold", 13, "个人回收", "SN-IP9-612", 96, 80), sellDate: dateKey(-1), sellChannel: "抖音", platformFee: 3000, logisticsCost: 1800 },
      { ...device("d8", "iPad Air 5", "256G", "紫色", "99新", 298000, 359900, "sold", 20, "华强北档口", "SN-AIR-523", 98, 44), sellDate: dateKey(), sellChannel: "微信", platformFee: 0, logisticsCost: 1800 },
      { ...device("d9", "iPad Pro 11 2021", "128G", "银色", "95新", 356000, 438800, "sold", 25, "闲鱼回收", "SN-PRO-213", 89, 210), sellDate: dateKey(), sellChannel: "闲鱼", platformFee: 6000, logisticsCost: 1800 },
      { ...device("d10", "iPad mini 6", "64G", "粉色", "9成新", 205000, 249900, "sold", 28, "个人回收", "SN-MINI-625", 87, 260), sellDate: dateKey(-3), sellChannel: "闲鱼", platformFee: 5200, logisticsCost: 1800, afterSaleCost: 6000 },
    ],
    orders: [
      order("o1", "d9", "iPad Pro 11 128G 银色", "杭州客户", "闲鱼", 438800, 54800, "pending", iso(0, 9, 28)),
      order("o2", "d8", "iPad Air 5 256G 紫色", "深圳客户", "微信", 359900, 61200, "shipped", iso(0, 13, 42)),
      order("o3", "d7", "iPad 9 64G 深空灰", "同城自提", "抖音", 169900, 31200, "done", iso(1, 16, 15)),
      order("o4", "d11", "iPad Pro 12.9 2020 256G", "批发客户", "批发", 398000, 42000, "done", iso(2, 11, 10)),
      { ...order("o5", "d10", "iPad mini 6 64G 粉色", "上海客户", "闲鱼", 249900, 38200, "aftersale", iso(3, 20, 5)), afterSaleCost: 6000, afterSaleReason: "描述不符", afterSaleProgress: "处理中" },
      order("o6", "d12", "iPad Air 4 64G 绿色", "南京客户", "微信", 219900, 27600, "done", iso(5, 14, 22)),
      order("o7", "d13", "iPad Pro 11 2020 256G", "宁波客户", "闲鱼", 338000, 32800, "done", monthIso(1, 10, 16)),
      order("o8", "d14", "iPad 10 256G 蓝色", "厦门客户", "小红书", 238000, 26800, "done", monthIso(2, 18, 15)),
      order("o9", "d15", "iPad Air 5 64G 蓝色", "苏州客户", "微信", 309900, 49600, "done", monthIso(3, 6, 13)),
      order("o10", "d16", "iPad mini 6 256G 星光色", "广州客户", "抖音", 278000, 36600, "done", monthIso(4, 22, 11)),
      order("o11", "d17", "iPad Pro 12.9 2021 512G", "批发客户", "批发", 518000, 40200, "done", monthIso(5, 12, 12)),
    ],
    agents: [
      { id: "a1", name: "阿哲", phone: "微信同号", commissionRate: 0.08, totalGmv: 962000, createdAt: iso(40) },
      { id: "a2", name: "小林数码", phone: "138****1212", commissionRate: 0.1, totalGmv: 623000, createdAt: iso(20) },
    ],
    repairOrders: [
      { id: "r1", deviceId: "d5", deviceName: "iPad Pro 12.9 2021 512G", type: "换电池", cost: 22000, status: "完成", note: "同步回写成本", createdAt: iso(10) },
      { id: "r2", deviceId: "d3", deviceName: "iPad mini 6 256G", type: "换壳", cost: 16000, status: "完成", note: "边角磕碰", createdAt: iso(6) },
    ],
    purchaseOrders: [
      { id: "p1", supplier: "华强北档口", sourcePlatform: "线下", deviceIds: ["d2", "d8"], totalCost: 556000, status: "done", returnedCount: 0, createdAt: iso(22) },
      { id: "p2", supplier: "个人回收", sourcePlatform: "闲鱼", deviceIds: ["d3", "d10"], totalCost: 431000, status: "done", returnedCount: 0, createdAt: iso(29) },
    ],
    qcReports: [
      { id: "q1", deviceId: "d1", deviceName: "iPad Pro 11 2022", inspector: "店员A", grade: "A", conclusion: "通过", screenCondition: "细微划痕", frameCondition: "完美", backCondition: "完美", cameraCondition: "正常", hasFaceId: true, hasTouchId: true, wifiOk: true, bluetoothOk: true, microphoneOk: true, speakerOk: true, buttonsOk: true, chargingOk: true, createdAt: iso(7) },
      { id: "q2", deviceId: "d5", deviceName: "iPad Pro 12.9 2021", inspector: "店员B", grade: "B", conclusion: "通过", screenCondition: "完美", frameCondition: "轻微磕碰", backCondition: "划痕", cameraCondition: "正常", hasFaceId: true, hasTouchId: true, wifiOk: true, bluetoothOk: true, microphoneOk: true, speakerOk: true, buttonsOk: true, chargingOk: true, createdAt: iso(31) },
    ],
    xianyuCopyExamples: [
      { id: "c1", title: "Air 5 靓机成交文案", model: "iPad Air 5", condition: "99新", tags: "成交快,自用", resultNote: "1天售出", score: 5, text: "机器成色很新，屏幕显示细腻，电池健康，适合学习办公。", createdAt: iso(12) },
      { id: "c2", title: "mini 6 真实描述", model: "iPad mini 6", condition: "9成新", tags: "真实瑕疵", resultNote: "咨询少", score: 4, text: "边框有轻微使用痕迹，功能都正常，适合随身阅读和追剧。", createdAt: iso(30) },
    ],
  });
}

function device(id, model, capacity, color, condition, purchaseCost, sellPrice, status, days, channel, serial, batteryHealth, cycleCount) {
  return {
    id,
    serial,
    model,
    capacity,
    color,
    network: "WiFi",
    condition,
    batteryHealth,
    cycleCount,
    idLockClean: true,
    accessories: "裸机",
    purchaseCost,
    purchaseChannel: channel,
    purchaseDate: dateKey(-days),
    sellPrice,
    status,
    repairCost: 0,
    platformFee: 0,
    logisticsCost: 0,
    afterSaleCost: 0,
    createdAt: dateKey(-days),
  };
}

function order(id, deviceId, deviceName, buyer, channel, amount, profit, status, createdAt) {
  return { id, deviceId, deviceName, buyer, channel, amount, profit, status, createdAt };
}

function monthlyStats(orders) {
  return Array.from({ length: 12 }, (_, index) => {
    const offset = index - 11;
    const key = monthKey(offset);
    const monthOrders = orders.filter((order) => startsWithDate(order.createdAt, key));
    return {
      label: monthLabel(key),
      key,
      gmv: sum(monthOrders, (order) => n(order.amount)),
      profit: sum(monthOrders, orderProfit),
      count: monthOrders.length,
    };
  });
}

function dailyStats(orders) {
  return Array.from({ length: 7 }, (_, index) => {
    const offset = index - 6;
    const key = dateKey(offset);
    const dayOrders = orders.filter((order) => startsWithDate(order.createdAt, key));
    return {
      label: key.slice(5),
      key,
      gmv: sum(dayOrders, (order) => n(order.amount)),
      profit: sum(dayOrders, orderProfit),
      count: dayOrders.length,
    };
  });
}

function channelStats(orders) {
  const map = new Map();
  orders.forEach((order) => {
    const channel = order.channel || "未知渠道";
    const item = map.get(channel) || { channel, gmv: 0, profit: 0, count: 0 };
    item.gmv += n(order.amount);
    item.profit += orderProfit(order);
    item.count += 1;
    map.set(channel, item);
  });
  return [...map.values()].sort((a, b) => b.gmv - a.gmv);
}

function modelProfitStats(devices) {
  const map = new Map();
  devices.forEach((device) => {
    const model = device.model || "未知型号";
    const item = map.get(model) || { model, count: 0, profit: 0, revenue: 0 };
    item.count += 1;
    item.profit += deviceProfit(device);
    item.revenue += n(device.sellPrice);
    map.set(model, item);
  });
  return [...map.values()].sort((a, b) => b.profit - a.profit);
}

function modelTurnoverStats(devices) {
  const map = new Map();
  devices.forEach((device) => {
    const days = soldTurnoverDays(device);
    const model = device.model || "未知型号";
    const item = map.get(model) || { model, count: 0, totalDays: 0 };
    item.count += 1;
    item.totalDays += days;
    map.set(model, item);
  });
  return [...map.values()]
    .map((item) => ({ ...item, avgDays: item.count ? Math.round(item.totalDays / item.count) : 0 }))
    .sort((a, b) => a.avgDays - b.avgDays);
}

function supplierStats(devices, orders) {
  const map = new Map();
  devices.forEach((device) => {
    const channel = device.purchaseChannel || "未知渠道";
    const item = map.get(channel) || { channel, count: 0, profit: 0, revenue: 0, afterSaleCount: 0 };
    item.count += 1;
    item.profit += deviceProfit(device);
    item.revenue += n(device.sellPrice);
    const hasAfterSale = orders.some(
      (order) => order.deviceId === device.id && (order.status === "aftersale" || n(order.afterSaleCost) > 0),
    );
    if (hasAfterSale) item.afterSaleCount += 1;
    map.set(channel, item);
  });
  return [...map.values()]
    .map((item) => ({
      ...item,
      avgProfit: item.count ? Math.round(item.profit / item.count) : 0,
      afterSaleRate: item.count ? item.afterSaleCount / item.count : 0,
    }))
    .sort((a, b) => b.profit - a.profit);
}

function customerStats(orders) {
  const map = new Map();
  orders.forEach((order) => {
    const name = order.buyer || "未知客户";
    const item = map.get(name) || { name, count: 0, totalAmount: 0, lastDate: order.createdAt || "", channels: new Set() };
    item.count += 1;
    item.totalAmount += n(order.amount);
    if (String(order.createdAt || "").localeCompare(item.lastDate) > 0) item.lastDate = order.createdAt || "";
    if (order.channel) item.channels.add(order.channel);
    map.set(name, item);
  });
  return [...map.values()]
    .map((item) => ({ ...item, channels: [...item.channels] }))
    .sort((a, b) => b.totalAmount - a.totalAmount);
}

function inventoryAgeDist(stock) {
  return {
    "0-7天": stock.filter((device) => stockDays(device) <= 7).length,
    "8-15天": stock.filter((device) => stockDays(device) > 7 && stockDays(device) <= 15).length,
    "16-30天": stock.filter((device) => stockDays(device) > 15 && stockDays(device) <= 30).length,
    "30天+": stock.filter((device) => stockDays(device) > 30).length,
  };
}

function latestMarketPrices(raw) {
  if (!raw || typeof raw !== "object") return [];
  return Object.entries(raw)
    .map(([model, history]) => {
      const rows = Array.isArray(history) ? history : [];
      const last = rows[rows.length - 1] || {};
      return { model, date: last.date || "", price: n(last.price), history: rows };
    })
    .filter((item) => item.model)
    .sort((a, b) => String(b.date).localeCompare(String(a.date)));
}

function qcReportStats(reports) {
  const passed = reports.filter((report) => report.conclusion === "通过").length;
  const byGrade = {};
  reports.forEach((report) => {
    const grade = report.grade || "未评级";
    byGrade[grade] = (byGrade[grade] || 0) + 1;
  });
  return {
    total: reports.length,
    passed,
    passRate: reports.length ? passed / reports.length : 0,
    byGrade,
  };
}

function repairOrderStats(repairs) {
  const totalCost = sum(repairs, (repair) => n(repair.cost));
  return {
    total: repairs.length,
    totalCost,
    avgCost: repairs.length ? Math.round(totalCost / repairs.length) : 0,
  };
}

function restockSuggestions(devices) {
  const map = new Map();
  const now = new Date();
  devices.forEach((device) => {
    const model = device.model || "未知型号";
    const item = map.get(model) || { model, inStock: 0, sales30d: 0, sales: [] };
    if (["in_stock", "listed"].includes(String(device.status || ""))) item.inStock += 1;
    if (device.status === "sold") {
      item.sales.push(n(device.sellPrice));
      const soldAt = toDate(device.sellDate || device.createdAt);
      if (soldAt && now.getTime() - soldAt.getTime() <= 30 * 86400000) item.sales30d += 1;
    }
    map.set(model, item);
  });
  return [...map.values()]
    .map((item) => {
      const suggestedStock = Math.ceil(item.sales30d * 1.5);
      const toPurchase = Math.max(0, suggestedStock - item.inStock);
      const avgSellPrice = avg(item.sales.map((value) => ({ value })), (x) => x.value);
      return {
        ...item,
        suggestedStock,
        toPurchase,
        avgSellPrice,
        maxPurchasePrice: avgSellPrice ? Math.round(avgSellPrice * 0.85) : 0,
      };
    })
    .filter((item) => item.sales30d > 0 || item.inStock > 0)
    .sort((a, b) => b.toPurchase - a.toPurchase || b.sales30d - a.sales30d);
}

function buildPurchasePlan(model, costFen) {
  if (!model || !costFen) return null;
  const devices = state.derived.devices.filter((device) => device.model === model);
  const sold = devices.filter((device) => device.status === "sold" && n(device.sellPrice) > 0);
  const inStock = devices.filter((device) => ["in_stock", "listed"].includes(String(device.status || "")));
  const market = state.derived.marketPrices.find((item) => item.model === model);
  const avgSell = avg(sold, (device) => n(device.sellPrice));
  const avgHistoricalCost = avg(sold, (device) => n(device.purchaseCost));
  const avgProfitValue = avg(sold, deviceProfit);
  const avgTurnover = averageTurnoverDays(sold);
  const maxByHistory = avgSell ? Math.round(avgSell * 0.82) : 0;
  const maxByMarket = market?.price ? Math.round(market.price * 1.02) : 0;
  const maxPurchase = Math.max(0, Math.min(...[maxByHistory, maxByMarket].filter(Boolean)));
  const feeReserve = Math.max(1800, Math.round(avgSell * 0.018));
  const repairReserve = Math.max(8000, Math.round(avg(sold, (device) => n(device.repairCost)) || 6000));
  const breakEven = costFen + feeReserve + repairReserve + 1800;
  const netProfit = avgSell ? avgSell - breakEven : 0;
  const risks = [];
  if (!avgSell) risks.push({ title: "缺少售价历史", text: "没有同型号成交价，只能小批试单。", badge: "数据少", tone: "warning" });
  if (!market?.price) risks.push({ title: "缺少今日行情", text: "建议先补批发价，再判断报价。", badge: "行情", tone: "warning" });
  if (maxPurchase && costFen > maxPurchase) risks.push({ title: "报价超上限", text: `当前高出建议上限 ${money(costFen - maxPurchase)}。`, badge: "压价", tone: "danger" });
  if (inStock.length >= 4) risks.push({ title: "库存偏重", text: `当前已有 ${inStock.length} 台同型号库存。`, badge: "库存", tone: "warning" });
  if (inStock.some((device) => stockDays(device) >= 15)) risks.push({ title: "已有滞销", text: "同型号存在超过 15 天库存。", badge: "滞销", tone: "danger" });
  if (avgTurnover > 18) risks.push({ title: "周转偏慢", text: `历史平均周转 ${avgTurnover} 天。`, badge: "现金", tone: "warning" });
  if (!risks.length) risks.push({ title: "没有明显硬伤", text: "重点复核成色、电池和隐藏维修成本。", badge: "可谈", tone: "good" });
  const score = Math.max(
    25,
    Math.min(
      95,
      76 +
        (netProfit > 35000 ? 10 : netProfit > 15000 ? 2 : -16) -
        (maxPurchase && costFen > maxPurchase ? 22 : 0) -
        inStock.length * 4 -
        (avgTurnover > 18 ? 8 : 0),
    ),
  );
  let decision = "谨慎收";
  let summary = "有利润空间，但需要控制数量和压一点价格。";
  let tone = "warn";
  if (!avgSell && !market?.price) {
    decision = "先别重仓";
    summary = "没有售价和行情锚点，只适合小批试单。";
    tone = "warn";
  } else if (maxPurchase && costFen > maxPurchase) {
    decision = "压价再收";
    summary = `建议最高 ${money(maxPurchase)}，当前报价偏高。`;
    tone = "bad";
  } else if (netProfit >= 35000 && score >= 70) {
    decision = "建议收";
    summary = "利润、周转和库存压力都在可控区间。";
    tone = "good";
  } else if (netProfit < 10000) {
    decision = "不建议";
    summary = "当前利润不足，快速出货也容易亏。";
    tone = "bad";
  }
  return {
    model,
    costFen,
    avgSell,
    avgHistoricalCost,
    avgProfitValue,
    avgTurnover,
    maxPurchase: maxPurchase || Math.max(0, Math.round((avgSell || market?.price || costFen) * 0.82)),
    breakEven,
    netProfit,
    score: Math.round(score),
    decision,
    summary,
    tone,
    risks,
  };
}

function modelOptions() {
  return [...new Set([...state.derived.devices.map((device) => device.model), ...state.derived.marketPrices.map((item) => item.model)].filter(Boolean))].sort();
}

function marketUpdatedToday(prices) {
  const today = dateKey();
  return prices.some((item) => item.date === today);
}

function monthSales(orders) {
  const key = monthKey(0);
  return sum(
    orders.filter((order) => startsWithDate(order.createdAt, key)),
    (order) => n(order.amount),
  );
}

function averageTurnoverDays(devices) {
  const values = devices.map(soldTurnoverDays).filter((value) => value > 0);
  return values.length ? Math.round(values.reduce((a, b) => a + b, 0) / values.length) : 0;
}

function soldTurnoverDays(device) {
  const purchase = toDate(device.purchaseDate);
  const sell = toDate(device.sellDate);
  if (!purchase || !sell) return 0;
  return Math.max(0, Math.round((sell.getTime() - purchase.getTime()) / 86400000));
}

function deviceRisk(device) {
  if (device.status === "sold") return { label: "已售", tone: "good" };
  if (device.status === "returned") return { label: "退回", tone: "bad" };
  if (stockDays(device) >= 15 && ["in_stock", "listed"].includes(String(device.status || ""))) return { label: "滞销", tone: "bad" };
  if (n(device.sellPrice) <= 0 && ["in_stock", "listed"].includes(String(device.status || ""))) return { label: "待定价", tone: "warn" };
  if (device.status === "listed") return { label: "在售", tone: "good" };
  if (device.status === "in_stock") return { label: "库存", tone: "info" };
  return { label: device.status || "未知", tone: "" };
}

function deviceRiskScore(device) {
  const risk = deviceRisk(device).label;
  return { 滞销: 4, 待定价: 3, 库存: 2, 在售: 1, 已售: 0 }[risk] || 0;
}

function orderStatusText(status) {
  return (
    {
      pending: "待发货",
      shipped: "已发货",
      done: "已完成",
      aftersale: "售后",
      cancelled: "作废",
    }[status] || status || "未知"
  );
}

function orderStatusTone(status) {
  return (
    {
      pending: "warn",
      shipped: "info",
      done: "good",
      aftersale: "bad",
      cancelled: "",
    }[status] || ""
  );
}

function expectedProfit(device) {
  return n(device.sellPrice) - n(device.purchaseCost) - n(device.repairCost);
}

function deviceProfit(device) {
  if (device.netProfit != null) return n(device.netProfit);
  if (n(device.sellPrice) <= 0) return 0;
  return n(device.sellPrice) - n(device.purchaseCost) - n(device.repairCost) - n(device.platformFee) - n(device.logisticsCost) - n(device.afterSaleCost);
}

function orderProfit(order) {
  if (order.netProfit != null) return n(order.netProfit);
  return n(order.profit) - n(order.afterSaleCost);
}

function stockDays(device) {
  if (Number.isFinite(Number(device.stockDays))) return Number(device.stockDays);
  const date = toDate(device.purchaseDate || device.createdAt);
  if (!date) return 0;
  return Math.max(0, Math.floor((Date.now() - date.getTime()) / 86400000));
}

function deviceName(device) {
  return [device.model, device.capacity, device.color].filter(Boolean).join(" ") || "未命名设备";
}

function exportCsv(type) {
  const rows =
    type === "orders"
      ? [["订单", "状态", "买家", "渠道", "成交额", "净利", "日期"], ...filteredOrders().map((o) => [o.deviceName, orderStatusText(o.status), o.buyer, o.channel, Math.round(n(o.amount) / 100), Math.round(orderProfit(o) / 100), o.createdAt])]
      : [["型号", "容量", "颜色", "网络", "成色", "序列号", "状态", "库龄", "成本", "售价", "毛利"], ...filteredDevices().map((d) => [d.model, d.capacity, d.color, d.network, d.condition, d.serial, deviceRisk(d).label, stockDays(d), Math.round(n(d.purchaseCost) / 100), n(d.sellPrice) ? Math.round(n(d.sellPrice) / 100) : "", n(d.sellPrice) ? Math.round((d.status === "sold" ? deviceProfit(d) : expectedProfit(d)) / 100) : ""])];
  const csv = `\uFEFF${rows.map((row) => row.map(csvCell).join(",")).join("\n")}`;
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `deepsell_${type}_${dateKey()}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}

function csvCell(value) {
  const text = String(value ?? "");
  const escaped = text.replaceAll('"', '""');
  return /[",\n，]/.test(escaped) ? `"${escaped}"` : escaped;
}

async function setDeviceStatus(id, status) {
  const device = state.data.devices.find((item) => item.id === id);
  if (!device) return;
  device.status = status;
  await commitData(status === "listed" ? "上架状态" : "库存状态");
  showDeviceDrawer(id);
}

async function saveDevicePrice(id) {
  const input = document.querySelector("#drawerPrice");
  const price = yuanToFen(input?.value || "");
  const device = state.data.devices.find((item) => item.id === id);
  if (!device) return;
  device.sellPrice = price;
  if (price > 0 && device.status === "in_stock") device.status = "listed";
  await commitData("设备价格");
  showDeviceDrawer(id);
}

async function setOrderStatus(id, status) {
  const order = state.data.orders.find((item) => item.id === id);
  if (!order) return;
  order.status = status;
  await commitData("订单状态");
  showOrderDrawer(id);
}

function drawLineChart(canvas, points, options) {
  if (!canvas) return;
  drawCanvas(canvas, (ctx, width, height) => {
    const pad = { left: 54, right: 20, top: 20, bottom: 36 };
    const innerW = width - pad.left - pad.right;
    const innerH = height - pad.top - pad.bottom;
    const primary = points.map((point) => n(point[options.primary]));
    const secondary = points.map((point) => n(point[options.secondary]));
    const max = Math.max(1, ...primary, ...secondary.map((v) => Math.max(0, v)));
    const min = Math.min(0, ...secondary);
    const range = Math.max(1, max - min);
    const x = (index) => pad.left + (innerW * index) / Math.max(1, points.length - 1);
    const y = (value) => pad.top + innerH - ((value - min) / range) * innerH;

    ctx.strokeStyle = "rgba(255,255,255,.065)";
    ctx.lineWidth = 1;
    ctx.font = "12px system-ui, sans-serif";
    ctx.fillStyle = cssVar("--faint");
    for (let i = 0; i <= 4; i += 1) {
      const value = min + (range * i) / 4;
      const ty = y(value);
      ctx.beginPath();
      ctx.moveTo(pad.left, ty);
      ctx.lineTo(width - pad.right, ty);
      ctx.stroke();
      ctx.fillText(moneyShort(value), 8, ty + 4);
    }
    points.forEach((point, index) => {
      if (index % 2 && points.length > 8) return;
      ctx.fillText(point.label, x(index) - 12, height - 10);
    });
    drawAreaLine(ctx, primary, x, y, "rgba(41, 213, 165, .18)", cssVar("--accent"), height - pad.bottom);
    drawLine(ctx, secondary, x, y, cssVar("--blue"));
    ctx.fillStyle = cssVar("--muted");
    ctx.fillText(options.primaryLabel, width - 155, 18);
    ctx.fillText(options.secondaryLabel, width - 86, 18);
  });
}

function drawDonut(canvas, segments) {
  if (!canvas) return;
  drawCanvas(canvas, (ctx, width, height) => {
    const total = Math.max(1, sum(segments, (segment) => segment.value));
    const cx = width / 2;
    const cy = height / 2;
    const radius = Math.min(width, height) * 0.42;
    const thickness = radius * 0.42;
    let start = -Math.PI / 2;
    segments.forEach((segment) => {
      const angle = (segment.value / total) * Math.PI * 2;
      ctx.beginPath();
      ctx.arc(cx, cy, radius, start, start + angle);
      ctx.arc(cx, cy, radius - thickness, start + angle, start, true);
      ctx.closePath();
      ctx.fillStyle = segment.color;
      ctx.fill();
      ctx.strokeStyle = cssVar("--surface");
      ctx.lineWidth = 3;
      ctx.stroke();
      start += angle;
    });
  });
}

function drawBars(canvas, values) {
  if (!canvas) return;
  drawCanvas(canvas, (ctx, width, height) => {
    const max = Math.max(1, ...values);
    const gap = 12;
    const barW = (width - gap * (values.length + 1)) / values.length;
    values.forEach((value, index) => {
      const h = ((height - 24) * value) / max;
      const x = gap + index * (barW + gap);
      const y = height - h - 10;
      ctx.fillStyle = [cssVar("--accent"), cssVar("--blue"), cssVar("--amber"), cssVar("--red")][index % 4];
      roundRect(ctx, x, y, barW, h, 6);
      ctx.fill();
    });
  });
}

function drawMiniChart(canvas, values) {
  if (!canvas) return;
  drawCanvas(canvas, (ctx, width, height) => {
    const min = Math.min(...values);
    const max = Math.max(...values);
    const range = Math.max(1, max - min);
    const x = (index) => (width * index) / Math.max(1, values.length - 1);
    const y = (value) => height - 9 - ((height - 18) * (value - min)) / range;
    drawAreaLine(ctx, values, x, y, "rgba(41, 213, 165, .18)", cssVar("--accent"), height - 9);
  });
}

function drawAreaLine(ctx, values, x, y, fill, stroke, baseY) {
  ctx.beginPath();
  values.forEach((value, index) => {
    if (index === 0) ctx.moveTo(x(index), y(value));
    else ctx.lineTo(x(index), y(value));
  });
  ctx.lineTo(x(values.length - 1), baseY);
  ctx.lineTo(x(0), baseY);
  ctx.closePath();
  ctx.fillStyle = fill;
  ctx.fill();
  drawLine(ctx, values, x, y, stroke);
}

function drawLine(ctx, values, x, y, stroke) {
  ctx.strokeStyle = stroke;
  ctx.lineWidth = 3;
  ctx.lineJoin = "round";
  ctx.lineCap = "round";
  ctx.beginPath();
  values.forEach((value, index) => {
    if (index === 0) ctx.moveTo(x(index), y(value));
    else ctx.lineTo(x(index), y(value));
  });
  ctx.stroke();
}

function drawCanvas(canvas, draw) {
  const rect = canvas.getBoundingClientRect();
  const scale = window.devicePixelRatio || 1;
  const width = Math.max(120, Math.floor(rect.width || canvas.width));
  const height = Math.max(80, Math.floor(rect.height || canvas.height));
  canvas.width = Math.floor(width * scale);
  canvas.height = Math.floor(height * scale);
  const ctx = canvas.getContext("2d");
  ctx.setTransform(scale, 0, 0, scale, 0, 0);
  ctx.clearRect(0, 0, width, height);
  draw(ctx, width, height);
}

function roundRect(ctx, x, y, width, height, radius) {
  const r = Math.min(radius, width / 2, height / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + width - r, y);
  ctx.quadraticCurveTo(x + width, y, x + width, y + r);
  ctx.lineTo(x + width, y + height - r);
  ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
  ctx.lineTo(x + r, y + height);
  ctx.quadraticCurveTo(x, y + height, x, y + height - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

function currentRoute() {
  const hash = location.hash.replace("#", "");
  return routes[hash] ? hash : "overview";
}

function setRoute(route) {
  state.route = routes[route] ? route : "overview";
  location.hash = state.route;
  renderApp();
}

function dateKey(offset = 0) {
  const d = new Date();
  d.setDate(d.getDate() + offset);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function monthKey(offset = 0) {
  const d = new Date();
  d.setMonth(d.getMonth() + offset);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

function monthLabel(key) {
  return `${Number(String(key).slice(5, 7))}月`;
}

function startsWithDate(raw, key) {
  return String(raw || "").startsWith(key);
}

function toDate(raw) {
  if (!raw) return null;
  const date = new Date(String(raw));
  return Number.isNaN(date.getTime()) ? null : date;
}

function relativeTime(date) {
  if (!date) return "未知";
  const diff = Math.max(0, Date.now() - date.getTime());
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return "刚刚";
  if (minutes < 60) return `${minutes} 分钟前`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} 小时前`;
  return dateTimeFmt.format(date);
}

function shortDate(raw) {
  const text = String(raw || "");
  if (text.length >= 10) return text.slice(0, 10);
  return text || "--";
}

function syncMeta(data) {
  const settings = data && typeof data.settings === "object" ? data.settings : {};
  const meta = settings && typeof settings.syncMeta === "object" ? settings.syncMeta : {};
  return meta || {};
}

function money(fen) {
  return `¥${moneyFmt.format(Math.round(n(fen) / 100))}`;
}

function moneyShort(fen) {
  const yuan = n(fen) / 100;
  if (Math.abs(yuan) >= 10000) return `${(yuan / 10000).toFixed(1)}万`;
  return `${Math.round(yuan)}`;
}

function percent(value) {
  return `${Math.round(n(value) * 1000) / 10}%`;
}

function compareText(current, previous) {
  const diff = previous ? (current - previous) / previous : 0;
  return `${diff >= 0 ? "+" : ""}${percent(diff)} vs 昨日`;
}

function yuanToFen(value) {
  const parsed = Number(String(value || "").trim());
  return Number.isFinite(parsed) && parsed > 0 ? Math.round(parsed * 100) : 0;
}

function avg(items, selector) {
  if (!items.length) return 0;
  return Math.round(sum(items, selector) / items.length);
}

function sum(items, selector) {
  return items.reduce((total, item) => total + selector(item), 0);
}

function n(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
}

function array(value) {
  return Array.isArray(value) ? value : [];
}

function cssVar(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

function esc(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function toast(message) {
  els.toast.textContent = message;
  els.toast.hidden = false;
  window.clearTimeout(toast.timer);
  toast.timer = window.setTimeout(() => {
    els.toast.hidden = true;
  }, 2400);
}

document.addEventListener("click", (event) => {
  const routeButton = event.target.closest("[data-route]");
  if (routeButton) {
    setRoute(routeButton.dataset.route);
    return;
  }
  const inventoryButton = event.target.closest("[data-inventory-status]");
  if (inventoryButton) {
    state.inventoryStatus = inventoryButton.dataset.inventoryStatus;
    renderInventory();
    return;
  }
  const orderButton = event.target.closest("[data-order-status]");
  if (orderButton) {
    state.orderStatus = orderButton.dataset.orderStatus;
    renderOrders();
    return;
  }
  const deviceRowEl = event.target.closest("[data-device-id]");
  if (deviceRowEl) {
    showDeviceDrawer(deviceRowEl.dataset.deviceId);
    return;
  }
  const orderRowEl = event.target.closest("[data-order-id]");
  if (orderRowEl) {
    showOrderDrawer(orderRowEl.dataset.orderId);
    return;
  }
  const exportButton = event.target.closest("[data-export]");
  if (exportButton) {
    exportCsv(exportButton.dataset.export);
    return;
  }
  const closeButton = event.target.closest("[data-close-drawer]");
  if (closeButton || event.target === els.drawerBackdrop) {
    closeDrawer(false);
    return;
  }
  const deviceStatusButton = event.target.closest("[data-device-status]");
  if (deviceStatusButton) {
    const [id, status] = deviceStatusButton.dataset.deviceStatus.split(":");
    setDeviceStatus(id, status);
    return;
  }
  const priceButton = event.target.closest("[data-save-price]");
  if (priceButton) {
    saveDevicePrice(priceButton.dataset.savePrice);
    return;
  }
  const orderStatusChange = event.target.closest("[data-order-status-change]");
  if (orderStatusChange) {
    const [id, status] = orderStatusChange.dataset.orderStatusChange.split(":");
    setOrderStatus(id, status);
  }
});

els.search.addEventListener("input", (event) => {
  state.query = event.target.value;
  if (state.route === "inventory") renderInventory();
  else if (state.route === "orders") renderOrders();
});

els.refresh.addEventListener("click", loadData);

window.addEventListener("hashchange", () => {
  const next = currentRoute();
  if (next !== state.route) setRoute(next);
});

window.addEventListener("resize", () => {
  if (!state.derived) return;
  const route = state.route;
  if (route === "overview") renderOverview();
  if (route === "analytics") renderAnalytics();
});

document.addEventListener("input", (event) => {
  if (event.target.id === "quoteCost") {
    state.quoteCost = event.target.value;
    renderOperations();
    const input = document.querySelector("#quoteCost");
    if (input) {
      input.focus();
    }
  }
});

document.addEventListener("change", (event) => {
  if (event.target.id === "quoteModel") {
    state.quoteModel = event.target.value;
    renderOperations();
  }
});

loadData();
window.setInterval(loadData, 60000);
