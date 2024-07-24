#include <string.h>
#include <jni.h>
#include <stdio.h>
#include <android/log.h>
#include <openssl/md5.h>
#include <openssl/blowfish.h>
#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/buffer.h>

char* base64_decode(const char* input, int length, int* output_length) {
    BIO* bio, * b64;
    char* output = (char*)malloc(length);
    if (output == NULL) {
        return NULL;
    }

    bio = BIO_new_mem_buf((void*)input, length);
    if (bio == NULL) {
        free(output);
        return NULL;
    }

    b64 = BIO_new(BIO_f_base64());
    bio = BIO_push(b64, bio);

    BIO_set_flags(bio, BIO_FLAGS_BASE64_NO_NL);

    *output_length = BIO_read(bio, output, length);
    if (*output_length <= 0) {
        free(output);
        BIO_free_all(bio);
        return NULL;
    }

    BIO_free_all(bio);

    output[*output_length] = '\0';

    return output;
}

JNIEXPORT void JNICALL Java_s_s_saturn_Deezer_decryptFile(JNIEnv *env, jobject obj, jstring jTrackId, jstring jInputFilename, jstring jOutputFilename) {
    //Get parameters from jstring to base C
    const char *inputFilename = (*env)->GetStringUTFChars(env, jInputFilename, NULL);
    const char *outputFilename = (*env)->GetStringUTFChars(env, jOutputFilename, NULL);
    const char *trackId = (*env)->GetStringUTFChars(env, jTrackId, NULL);

    //Calculate track id MD5
    unsigned char digest[MD5_DIGEST_LENGTH];
    MD5_CTX context;
    MD5_Init(&context);
    MD5_Update(&context, trackId, strlen(trackId));
    MD5_Final(digest, &context);
    char MD5String[33];
    for (int i = 0; i < 16; i++)
        sprintf(&MD5String[i*2], "%02x", (unsigned int)digest[i]);

    char bfKey[17] = "";

    const char* base64_input = "ZzRlbDU4d2MwenZmOW5hMQ==";
    int decoded_length;
    char* decoded = base64_decode(base64_input, strlen(base64_input), &decoded_length);

    const char secret[decoded_length];
    strcpy(secret, decoded);
    free(decoded);

    for(int i=0; i<16; i++)
        bfKey[i] = MD5String[i] ^ MD5String[i+16] ^ secret[i];
    //__android_log_print(ANDROID_LOG_WARN, "DECRYPTOR", "TRACK: %s, MD5: %s, KEY: %s", trackId, MD5String, bfKey);
    BF_KEY key;
    BF_set_key(&key, 16, bfKey);

    //Open files
    FILE *ifile = fopen(inputFilename, "rb");
    FILE *ofile = fopen(outputFilename, "wb");
    //Decrypt
    int i=0;
    while (!feof(ifile)) {
        unsigned char buffer[2048];
        int read = fread(buffer, 1, 2048, ifile);
        if (i % 3 == 0 && read == 2048) {
            unsigned char decrypted[2048];
            unsigned char IV[8] = {0,1,2,3,4,5,6,7};
            BF_cbc_encrypt(buffer, decrypted, 2048, &key, IV, BF_DECRYPT);
            fwrite(decrypted, sizeof(unsigned char), sizeof(decrypted), ofile);
        } else {
            int written = fwrite(buffer, sizeof(unsigned char), (size_t)read, ofile);
        }
        i++;
    }
    fclose(ifile);
    fclose(ofile);

    //Free the parameters
    (*env)->ReleaseStringUTFChars(env, jInputFilename, inputFilename);
    (*env)->ReleaseStringUTFChars(env, jOutputFilename, outputFilename);
    (*env)->ReleaseStringUTFChars(env, jTrackId, trackId);
}