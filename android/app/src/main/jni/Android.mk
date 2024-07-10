LOCAL_PATH := $(call my-dir)

#OpenSSL SSL
include $(CLEAR_VARS)
LOCAL_MODULE    		:= openssl
LOCAL_SRC_FILES			:= lib/$(TARGET_ARCH_ABI)/lib/libssl.a
include $(PREBUILT_STATIC_LIBRARY)

#OpenSSL Crypto
include $(CLEAR_VARS)
LOCAL_MODULE    		:= opencrypto
LOCAL_SRC_FILES 		:= lib/$(TARGET_ARCH_ABI)/lib/libcrypto.a
include $(PREBUILT_STATIC_LIBRARY)

#Decryptor
include $(CLEAR_VARS)
LOCAL_MODULE    		:= decryptor-jni
LOCAL_SRC_FILES 		:= decryptor-jni.c
LOCAL_SHARED_LIBRARIES 	:= openssl opencrypto
LOCAL_LDLIBS			:= -llog
include $(BUILD_SHARED_LIBRARY)
