package s.s.saturn;

import android.util.Log;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.security.MessageDigest;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;
import javax.crypto.spec.IvParameterSpec;

public class DeezerDecryptor {
    private final Cipher cipher;

    /**
     * Constructor initializes the key and cipher for the given track ID.
     * @param trackId Track ID used to generate decryption key
     * @throws Exception If there is an issue initializing the cipher
     */
    public DeezerDecryptor(String trackId) throws Exception {
        this.cipher = Cipher.getInstance("Blowfish/CBC/NoPadding");
        byte[] IV = {00, 01, 02, 03, 04, 05, 06, 07};
        SecretKeySpec Skey = new SecretKeySpec(getKey(trackId), "Blowfish");
        cipher.init(Cipher.DECRYPT_MODE, Skey, new IvParameterSpec(IV));
    }

    /**
     * Decrypts a file by reading it in chunks and decrypting every 3rd chunk of exactly 2048 bytes.
     * @param inputFilename The input file to decrypt
     * @param outputFilename The output file to write the decrypted data
     * @throws IOException If an I/O error occurs
     */
    public void decryptFile(String inputFilename, String outputFilename) throws IOException {
        try (FileInputStream fis = new FileInputStream(inputFilename);
             FileOutputStream fos = new FileOutputStream(outputFilename)) {
            byte[] buffer = new byte[2048];
            int bytesRead;
            int chunkCounter = 0;

            while ((bytesRead = fis.read(buffer)) != -1) {
                // Only every 3rd chunk of exactly 2048 bytes should be decrypted
                if (bytesRead == 2048 && (chunkCounter % 3) == 0) {
                    buffer = decryptChunk(buffer);
                }
                fos.write(buffer, 0, bytesRead);
                chunkCounter++;
            }
        } catch (IOException e) {
            throw e;
        }
    }

    /**
     * Converts a byte array to a hexadecimal string.
     * @param bytes Byte array to convert
     * @return Hexadecimal string representation of the byte array
     */
    public static String bytesToHex(byte[] bytes) {
        final char[] HEX_ARRAY = "0123456789ABCDEF".toCharArray();
        char[] hexChars = new char[bytes.length * 2];
        for (int j = 0; j < bytes.length; j++) {
            int v = bytes[j] & 0xFF;
            hexChars[j * 2] = HEX_ARRAY[v >>> 4];
            hexChars[j * 2 + 1] = HEX_ARRAY[v & 0x0F];
        }
        return new String(hexChars);
    }

    /**
     * Generates the Track decryption key based on the provided track ID and a secret.
     * @param id Track ID used to generate decryption key
     * @return Decryption key for Track
     */
    static byte[] getKey(String id) {
        final String secret = "g4el58wc0zvf9na1";
        try {
            MessageDigest md5 = MessageDigest.getInstance("MD5");
            md5.update(id.getBytes());
            byte[] md5id = md5.digest();
            String idmd5 = bytesToHex(md5id).toLowerCase();
            String key = "";
            for (int i = 0; i < 16; i++) {
                int s0 = idmd5.charAt(i);
                int s1 = idmd5.charAt(i + 16);
                int s2 = secret.charAt(i);
                key += (char) (s0 ^ s1 ^ s2);
            }
            return key.getBytes();
        } catch (Exception e) {
            Log.e("E", e.toString());
            return new byte[0];
        }
    }

    /**
     * Decrypts a 2048-byte chunk of data using the pre-initialized Blowfish cipher.
     * @param data 2048-byte chunk of data to decrypt
     * @return Decrypted 2048-byte chunk
     */
    private byte[] decryptChunk(byte[] data) {
        try {
            return cipher.doFinal(data);
        } catch (Exception e) {
            Log.e("D", e.toString());
            return new byte[0];
        }
    }

    /**
     * Decrypts a 2048-byte chunk of data using the Blowfish algorithm in CBC mode with no padding.
     * The decryption key and the initial vector (IV) are used to decrypt the data.
     * @param key Track key
     * @param data 2048-byte chunk of data to decrypt
     * @return Decrypted 2048-byte chunk
     */
    public static byte[] decryptChunk(byte[] key, byte[] data) {
        try {
            byte[] IV = {00, 01, 02, 03, 04, 05, 06, 07};
            SecretKeySpec Skey = new SecretKeySpec(key, "Blowfish");
            Cipher cipher = Cipher.getInstance("Blowfish/CBC/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, Skey, new IvParameterSpec(IV));
            return cipher.doFinal(data);
        } catch (Exception e) {
            Log.e("D", e.toString());
            return new byte[0];
        }
    }
}