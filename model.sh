#!/bin/bash
case "$1" in
  flash)
    #export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
    #export ANTHROPIC_AUTH_TOKEN="sk-9c0a3d690b804c64bcdbfde682a7162a"
    export ANTHROPIC_BASE_URL="http://192.168.1.190/"
    export ANTHROPIC_AUTH_TOKEN="sk-TEDAoA70XCFz2d6XhVgc1zUt5TCWBGYlRbSVYE1sXoEamWRX"	
    export ANTHROPIC_MODEL="deepseek-v4-pro[1m]"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash[1m]"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-flash[1m]"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro[1m]"
   #export API_TIMEOUT_MS="3000000"
    export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-flash[1m]"
    export CLAUDE_CODE_EFFORT_LEVEL="max"
   #export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
    ;;
  glm)
    export ANTHROPIC_BASE_URL="http://192.168.1.77:3000"
    export ANTHROPIC_AUTH_TOKEN="sk-t0xq70DezLUzRTUNTa9Di4ktFjn36gfp6RYjNHD2qlb44tkt"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air" #glm-4.5-air
    export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.1" #MiniMax-M3
    export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.2[1m]"
    export ANTHROPIC_MODEL="glm-5.2[1m]"
	export CLAUDE_CODE_EFFORT_LEVEL="max"
    ;;
  kimi)
    export ANTHROPIC_BASE_URL="http://192.168.1.190/"
    export ANTHROPIC_AUTH_TOKEN="sk-TEDAoA70XCFz2d6XhVgc1zUt5TCWBGYlRbSVYE1sXoEamWRX"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air" #glm-4.5-air
    export ANTHROPIC_DEFAULT_SONNET_MODEL="kimi-k2.7-code" #MiniMax-M3
    export ANTHROPIC_DEFAULT_OPUS_MODEL="kimi-k2.7-code"
    export ANTHROPIC_MODEL="kimi-k2.7-code"
	export CLAUDE_CODE_EFFORT_LEVEL="max"
    ;;
  xiaomi)
    export ANTHROPIC_BASE_URL="https://token-plan-cn.xiaomimimo.com/anthropic"
    export ANTHROPIC_AUTH_TOKEN="tp-c9lsclgzo01yun0iu7lgqqyo9qfj4jphfj5vvxp9z5qaww81"
    export ANTHROPIC_MODEL="mimo-v2.5-pro[1m]"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="mimo-v2.5-pro[1m]"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="mimo-v2.5-pro[1m]"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="mimo-v2.5-pro[1m]"
    export CLAUDE_CODE_SUBAGENT_MODEL="mimo-v2.5-pro[1m]"
	export CLAUDE_CODE_EFFORT_LEVEL="max"
    ;;
  qwen)
    export ANTHROPIC_BASE_URL="http://192.168.1.190/"
    export ANTHROPIC_AUTH_TOKEN="sk-TEDAoA70XCFz2d6XhVgc1zUt5TCWBGYlRbSVYE1sXoEamWRX"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air" #glm-4.5-air
    export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.1" #MiniMax-M3
    export ANTHROPIC_DEFAULT_OPUS_MODEL="qwen3.7-max"
    export ANTHROPIC_MODEL="qwen3.7-max"
	export CLAUDE_CODE_EFFORT_LEVEL="max"
    ;;
  *)
    echo "Usage: $0 {flash|glm|kimi|qwen|xiaomi}"
    exit 1
    ;;
esac
claude --dangerously-skip-permissions
