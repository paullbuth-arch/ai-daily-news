#include <jni.h>
#include <opus.h>
#include <cstring>
#include <vector>

#define TAG "OpusJni"

extern "C" {

/**
 * Creates an Opus decoder.
 * Signature: nativeCreate(II)J
 */
JNIEXPORT jlong JNICALL
Java_com_example_voskasr_audio_OpusDecoder_nativeCreate(JNIEnv *env, jobject thiz, jint sampleRate,
                                                  jint channels) {
    int error = 0;
    OpusDecoder *decoder = opus_decoder_create(sampleRate, channels, &error);
    if (error != OPUS_OK || decoder == nullptr) {
        return 0;
    }
    return reinterpret_cast<jlong>(decoder);
}

/**
 * Decodes one Opus frame into a 16-bit PCM output buffer.
 *
 * @param opusData   raw Opus packet bytes
 * @param pcmBuffer  output buffer (must be a direct ByteBuffer or short[] large enough)
 * @return number of decoded samples per channel, or <= 0 on error
 */
JNIEXPORT jint JNICALL
Java_com_example_voskasr_audio_OpusDecoder_nativeDecode(JNIEnv *env, jobject thiz, jlong handle,
                                                  jbyteArray opusData, jobject pcmBuffer) {
    if (handle == 0) {
        return -1;
    }

    OpusDecoder *decoder = reinterpret_cast<OpusDecoder *>(handle);

    jsize opusLen = env->GetArrayLength(opusData);
    if (opusLen <= 0) {
        return -2;
    }

    jbyte *opusBytes = env->GetByteArrayElements(opusData, nullptr);
    if (opusBytes == nullptr) {
        return -3;
    }

    // Output is written into a direct ByteBuffer as 16-bit PCM.
    jbyte *pcmPtr = reinterpret_cast<jbyte *>(env->GetDirectBufferAddress(pcmBuffer));
    if (pcmPtr == nullptr) {
        env->ReleaseByteArrayElements(opusData, opusBytes, JNI_ABORT);
        return -4;
    }

    jint maxSamples = env->GetDirectBufferCapacity(pcmBuffer) / sizeof(opus_int16);

    int decoded = opus_decode(decoder,
                              reinterpret_cast<const unsigned char *>(opusBytes),
                              opusLen,
                              reinterpret_cast<opus_int16 *>(pcmPtr),
                              maxSamples,
                              0);

    env->ReleaseByteArrayElements(opusData, opusBytes, JNI_ABORT);

    return decoded >= 0 ? decoded : -5;
}

/**
 * Destroys the Opus decoder.
 */
JNIEXPORT void JNICALL
Java_com_example_voskasr_audio_OpusDecoder_nativeDestroy(JNIEnv *env, jobject thiz, jlong handle) {
    if (handle != 0) {
        OpusDecoder *decoder = reinterpret_cast<OpusDecoder *>(handle);
        opus_decoder_destroy(decoder);
    }
}

} // extern "C"
