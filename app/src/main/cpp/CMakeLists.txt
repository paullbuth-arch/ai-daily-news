cmake_minimum_required(VERSION 3.10.2)
project(opus_jni)

set(OPUS_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/opus)

# libopus build configuration
add_definitions(-DOPUS_BUILD)
add_definitions(-DFLOAT_APPROX)
add_definitions(-DUSE_ALLOCA)

# Optimise the codec; keep symbols for debugging in debug builds.
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O2")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")

# Include paths used by libopus internals.
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${OPUS_ROOT}/include
    ${OPUS_ROOT}/celt
    ${OPUS_ROOT}/silk
    ${OPUS_ROOT}/silk/float
)

# Core Opus API sources.
set(OPUS_SRC
    ${OPUS_ROOT}/src/opus.c
    ${OPUS_ROOT}/src/opus_decoder.c
    ${OPUS_ROOT}/src/opus_encoder.c
    ${OPUS_ROOT}/src/opus_multistream.c
    ${OPUS_ROOT}/src/opus_multistream_encoder.c
    ${OPUS_ROOT}/src/opus_multistream_decoder.c
    ${OPUS_ROOT}/src/repacketizer.c
    ${OPUS_ROOT}/src/opus_projection_encoder.c
    ${OPUS_ROOT}/src/opus_projection_decoder.c
    ${OPUS_ROOT}/src/mapping_matrix.c
    ${OPUS_ROOT}/src/analysis.c
    ${OPUS_ROOT}/src/mlp.c
    ${OPUS_ROOT}/src/mlp_data.c
)

# CELT sources (generic C only, no platform asm/intrinsics).
set(CELT_SRC
    ${OPUS_ROOT}/celt/bands.c
    ${OPUS_ROOT}/celt/celt.c
    ${OPUS_ROOT}/celt/celt_encoder.c
    ${OPUS_ROOT}/celt/celt_decoder.c
    ${OPUS_ROOT}/celt/cwrs.c
    ${OPUS_ROOT}/celt/entcode.c
    ${OPUS_ROOT}/celt/entdec.c
    ${OPUS_ROOT}/celt/entenc.c
    ${OPUS_ROOT}/celt/kiss_fft.c
    ${OPUS_ROOT}/celt/laplace.c
    ${OPUS_ROOT}/celt/mathops.c
    ${OPUS_ROOT}/celt/mdct.c
    ${OPUS_ROOT}/celt/modes.c
    ${OPUS_ROOT}/celt/pitch.c
    ${OPUS_ROOT}/celt/celt_lpc.c
    ${OPUS_ROOT}/celt/quant_bands.c
    ${OPUS_ROOT}/celt/rate.c
    ${OPUS_ROOT}/celt/vq.c
)

# SILK sources (floating-point path).
set(SILK_SRC
    ${OPUS_ROOT}/silk/CNG.c
    ${OPUS_ROOT}/silk/code_signs.c
    ${OPUS_ROOT}/silk/init_decoder.c
    ${OPUS_ROOT}/silk/decode_core.c
    ${OPUS_ROOT}/silk/decode_frame.c
    ${OPUS_ROOT}/silk/decode_parameters.c
    ${OPUS_ROOT}/silk/decode_indices.c
    ${OPUS_ROOT}/silk/decode_pulses.c
    ${OPUS_ROOT}/silk/decoder_set_fs.c
    ${OPUS_ROOT}/silk/dec_API.c
    ${OPUS_ROOT}/silk/enc_API.c
    ${OPUS_ROOT}/silk/encode_indices.c
    ${OPUS_ROOT}/silk/encode_pulses.c
    ${OPUS_ROOT}/silk/gain_quant.c
    ${OPUS_ROOT}/silk/interpolate.c
    ${OPUS_ROOT}/silk/LP_variable_cutoff.c
    ${OPUS_ROOT}/silk/NLSF_decode.c
    ${OPUS_ROOT}/silk/NSQ.c
    ${OPUS_ROOT}/silk/NSQ_del_dec.c
    ${OPUS_ROOT}/silk/PLC.c
    ${OPUS_ROOT}/silk/shell_coder.c
    ${OPUS_ROOT}/silk/tables_gain.c
    ${OPUS_ROOT}/silk/tables_LTP.c
    ${OPUS_ROOT}/silk/tables_NLSF_CB_NB_MB.c
    ${OPUS_ROOT}/silk/tables_NLSF_CB_WB.c
    ${OPUS_ROOT}/silk/tables_other.c
    ${OPUS_ROOT}/silk/tables_pitch_lag.c
    ${OPUS_ROOT}/silk/tables_pulses_per_block.c
    ${OPUS_ROOT}/silk/VAD.c
    ${OPUS_ROOT}/silk/control_audio_bandwidth.c
    ${OPUS_ROOT}/silk/quant_LTP_gains.c
    ${OPUS_ROOT}/silk/VQ_WMat_EC.c
    ${OPUS_ROOT}/silk/HP_variable_cutoff.c
    ${OPUS_ROOT}/silk/NLSF_encode.c
    ${OPUS_ROOT}/silk/NLSF_VQ.c
    ${OPUS_ROOT}/silk/NLSF_unpack.c
    ${OPUS_ROOT}/silk/NLSF_del_dec_quant.c
    ${OPUS_ROOT}/silk/process_NLSFs.c
    ${OPUS_ROOT}/silk/stereo_LR_to_MS.c
    ${OPUS_ROOT}/silk/stereo_MS_to_LR.c
    ${OPUS_ROOT}/silk/check_control_input.c
    ${OPUS_ROOT}/silk/control_SNR.c
    ${OPUS_ROOT}/silk/init_encoder.c
    ${OPUS_ROOT}/silk/control_codec.c
    ${OPUS_ROOT}/silk/A2NLSF.c
    ${OPUS_ROOT}/silk/ana_filt_bank_1.c
    ${OPUS_ROOT}/silk/biquad_alt.c
    ${OPUS_ROOT}/silk/bwexpander_32.c
    ${OPUS_ROOT}/silk/bwexpander.c
    ${OPUS_ROOT}/silk/debug.c
    ${OPUS_ROOT}/silk/decode_pitch.c
    ${OPUS_ROOT}/silk/inner_prod_aligned.c
    ${OPUS_ROOT}/silk/lin2log.c
    ${OPUS_ROOT}/silk/log2lin.c
    ${OPUS_ROOT}/silk/LPC_analysis_filter.c
    ${OPUS_ROOT}/silk/LPC_inv_pred_gain.c
    ${OPUS_ROOT}/silk/table_LSF_cos.c
    ${OPUS_ROOT}/silk/NLSF2A.c
    ${OPUS_ROOT}/silk/NLSF_stabilize.c
    ${OPUS_ROOT}/silk/NLSF_VQ_weights_laroia.c
    ${OPUS_ROOT}/silk/pitch_est_tables.c
    ${OPUS_ROOT}/silk/resampler.c
    ${OPUS_ROOT}/silk/resampler_down2_3.c
    ${OPUS_ROOT}/silk/resampler_down2.c
    ${OPUS_ROOT}/silk/resampler_private_AR2.c
    ${OPUS_ROOT}/silk/resampler_private_down_FIR.c
    ${OPUS_ROOT}/silk/resampler_private_IIR_FIR.c
    ${OPUS_ROOT}/silk/resampler_private_up2_HQ.c
    ${OPUS_ROOT}/silk/resampler_rom.c
    ${OPUS_ROOT}/silk/sigm_Q15.c
    ${OPUS_ROOT}/silk/sort.c
    ${OPUS_ROOT}/silk/sum_sqr_shift.c
    ${OPUS_ROOT}/silk/stereo_decode_pred.c
    ${OPUS_ROOT}/silk/stereo_encode_pred.c
    ${OPUS_ROOT}/silk/stereo_find_predictor.c
    ${OPUS_ROOT}/silk/stereo_quant_pred.c
    ${OPUS_ROOT}/silk/LPC_fit.c
)

# SILK floating-point implementation.
set(SILK_FLOAT_SRC
    ${OPUS_ROOT}/silk/float/apply_sine_window_FLP.c
    ${OPUS_ROOT}/silk/float/corrMatrix_FLP.c
    ${OPUS_ROOT}/silk/float/encode_frame_FLP.c
    ${OPUS_ROOT}/silk/float/find_LPC_FLP.c
    ${OPUS_ROOT}/silk/float/find_LTP_FLP.c
    ${OPUS_ROOT}/silk/float/find_pitch_lags_FLP.c
    ${OPUS_ROOT}/silk/float/find_pred_coefs_FLP.c
    ${OPUS_ROOT}/silk/float/LPC_analysis_filter_FLP.c
    ${OPUS_ROOT}/silk/float/LTP_analysis_filter_FLP.c
    ${OPUS_ROOT}/silk/float/LTP_scale_ctrl_FLP.c
    ${OPUS_ROOT}/silk/float/noise_shape_analysis_FLP.c
    ${OPUS_ROOT}/silk/float/process_gains_FLP.c
    ${OPUS_ROOT}/silk/float/regularize_correlations_FLP.c
    ${OPUS_ROOT}/silk/float/residual_energy_FLP.c
    ${OPUS_ROOT}/silk/float/warped_autocorrelation_FLP.c
    ${OPUS_ROOT}/silk/float/wrappers_FLP.c
    ${OPUS_ROOT}/silk/float/autocorrelation_FLP.c
    ${OPUS_ROOT}/silk/float/burg_modified_FLP.c
    ${OPUS_ROOT}/silk/float/bwexpander_FLP.c
    ${OPUS_ROOT}/silk/float/energy_FLP.c
    ${OPUS_ROOT}/silk/float/inner_product_FLP.c
    ${OPUS_ROOT}/silk/float/k2a_FLP.c
    ${OPUS_ROOT}/silk/float/LPC_inv_pred_gain_FLP.c
    ${OPUS_ROOT}/silk/float/pitch_analysis_core_FLP.c
    ${OPUS_ROOT}/silk/float/scale_copy_vector_FLP.c
    ${OPUS_ROOT}/silk/float/scale_vector_FLP.c
    ${OPUS_ROOT}/silk/float/schur_FLP.c
    ${OPUS_ROOT}/silk/float/sort_FLP.c
)

add_library(opus STATIC
    ${OPUS_SRC}
    ${CELT_SRC}
    ${SILK_SRC}
    ${SILK_FLOAT_SRC}
)

# JNI wrapper for the Android Opus decoder.
add_library(opus_jni SHARED
    opus_jni.cpp
)

target_link_libraries(opus_jni
    opus
    log
)
