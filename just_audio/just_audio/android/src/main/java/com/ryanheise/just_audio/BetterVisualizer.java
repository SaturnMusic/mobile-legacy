package com.ryanheise.just_audio;

import android.media.audiofx.Visualizer;
import io.flutter.plugin.common.BinaryMessenger;

public class BetterVisualizer {
    private Visualizer visualizer;
    private final BetterEventChannel waveformEventChannel;
    private final BetterEventChannel fftEventChannel;
    private Integer audioSessionId;
    private int captureRate;
    private int captureSize;
    private boolean enableWaveform;
    private boolean enableFft;
    private boolean pendingStartRequest;
    private boolean hasPermission;

    public BetterVisualizer(final BinaryMessenger messenger, String id) {
        waveformEventChannel = new BetterEventChannel(messenger, "com.ryanheise.just_audio.waveform_events." + id);
        fftEventChannel = new BetterEventChannel(messenger, "com.ryanheise.just_audio.fft_events." + id);
    }

    public int getSamplingRate() {
        if (visualizer == null) {
            throw new IllegalStateException("Visualizer is not initialized.");
        }
        return visualizer.getSamplingRate();
    }
    

    public void setHasPermission(boolean hasPermission) {
        this.hasPermission = hasPermission;
    }

    public void onAudioSessionId(Integer audioSessionId) {
        this.audioSessionId = audioSessionId;
        if (audioSessionId != null && hasPermission && pendingStartRequest) {
            start(captureRate, captureSize, enableWaveform, enableFft);
        }
    }

    public void start(Integer captureRate, Integer captureSize, final boolean enableWaveform, final boolean enableFft) {
        if (visualizer != null) {
            return;  // Visualizer already initialized
        }
    
        if (captureRate == null) {
            captureRate = Visualizer.getMaxCaptureRate() / 2;
        } else if (captureRate > Visualizer.getMaxCaptureRate()) {
            captureRate = Visualizer.getMaxCaptureRate();
        }
    
        if (captureSize == null) {
            captureSize = Visualizer.getCaptureSizeRange()[1];
        } else if (captureSize > Visualizer.getCaptureSizeRange()[1]) {
            captureSize = Visualizer.getCaptureSizeRange()[1];
        } else if (captureSize < Visualizer.getCaptureSizeRange()[0]) {
            captureSize = Visualizer.getCaptureSizeRange()[0];
        }
    
        this.enableWaveform = enableWaveform;
        this.enableFft = enableFft;
        this.captureRate = captureRate;
        this.captureSize = captureSize;
    
        if (audioSessionId == null || !hasPermission) {
            pendingStartRequest = true;
            return;
        }
    
        pendingStartRequest = false;
    
        try {
            visualizer = new Visualizer(audioSessionId);
            visualizer.setEnabled(false); // Ensure visualizer is disabled before configuration
    
            visualizer.setCaptureSize(captureSize);
            visualizer.setDataCaptureListener(new Visualizer.OnDataCaptureListener() {
                @Override
                public void onWaveFormDataCapture(Visualizer visualizer, byte[] waveform, int samplingRate) {
                    waveformEventChannel.success(waveform);
                }
    
                @Override
                public void onFftDataCapture(Visualizer visualizer, byte[] fft, int samplingRate) {
                    fftEventChannel.success(fft);
                }
            }, captureRate, enableWaveform, enableFft);
    
            visualizer.setEnabled(true);
        } catch (IllegalStateException e) {
            e.printStackTrace();
            dispose();
        }
    }    
    

    public void stop() {
        if (visualizer == null) return;
        visualizer.setDataCaptureListener(null, captureRate, enableWaveform, enableFft);
        visualizer.setEnabled(false);
        visualizer.release();
        visualizer = null;
    }

    public void dispose() {
        stop();
        waveformEventChannel.endOfStream();
        fftEventChannel.endOfStream();
    }    
}
