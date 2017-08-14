classdef z
    % Z
    %   This class proposes some basic methods for audio signal processing.
    %
    % Z Methods:
    %   stft - Short-Time Fourier Transform (STFT)
    %   istft - Inverse STFT
    %   mfcc - Mel Frequency Cepstrum Coefficients (MFCCs)
    %   cqt - Constant Q Transform (CQT)
    %   cqtkernel - CQT kernel
    %   chromagram - Chromagram
    %
    % See also http://zafarrafii.com
    %
    % Author
    %   Zafar Rafii
    %   zafarrafii@gmail.com
    %   08/14/17
    %
    % References
    %   Judith C. Brown, Calculation of a constant Q spectral transform,
    %   The Journal of the Acoustical Society of America, 89, 1991.
    %
    %   Judith C. Brown and Miller S. Puckette, An efficient algorithm for
    %   the calculation of a constant Q transform, The Journal of the
    %   Acoustical Society of America, 95, 1992.
    
    methods (Static = true)
        
        function audio_stft = stft(audio_signal,window_function,step_length)
            % Short-Time Fourier Transform (STFT)
            %   Here is some help text for this method.
            %   
            %   Example:
            %       % Audio signal and sample rate in Hz
            %       [audio_signal,sample_rate] = audioread('audio_file.wav');
            %
            %       % Window duration in seconds (audio is stationary around 40 milliseconds)
            %       window_duration = 0.04;
            %
            %       % Window length in samples (power of 2 for fast FFT and constant overlap-add (COLA))
            %       window_length = 2^nextpow2(window_duration*sample_rate);
            %
            %       % Window function (periodic Hamming window for COLA)
            %       window_function = hamming(window_length,'periodic');
            %
            %       % Step length in samples (half the window length for COLA)
            %       step_length = window_length/2;
            % 
            %       % STFT of the left channel
            %       audio_stft = z.stft(audio_signal(:,1),window_function,step_length);
            %
            %       % Magnitude spectrogram (without the DC component and the mirrored frequencies)
            %       audio_spectrogram = abs(audio_stft(2:window_length/2+1,:));
            %
            %       % Spectrogram displayed in dB
            %       figure
            %       imagesc(db(audio_spectrogram))
            %       axis xy
            %       colormap(jet)
            %       title('Spectrogram')
            %       xlabel('Time')
            %       ylabel('Frequency')
            %
            %   See also fft, istft
            
            % Number of samples
            number_samples = length(audio_signal);
            
            % Window length in samples
            window_length = length(window_function);
            
            % Number of time frames
            number_times = ceil((window_length-step_length+number_samples)/step_length);
            
            % Zero-padding at the start and end to center the windows
            audio_signal = [zeros(window_length-step_length,1);audio_signal; ...
                zeros(number_times*step_length-number_samples,1)];
            
            % Initialize the STFT
            audio_stft = zeros(window_length,number_times);
            
            % Loop over the time frames
            for time_index = 1:number_times
                
                % Window the signal
                sample_index = step_length*(time_index-1);
                audio_stft(:,time_index) ...
                    = audio_signal(1+sample_index:window_length+sample_index).*window_function;
                
            end
            
            % Fourier transform of the frames
            audio_stft = fft(audio_stft);
            
        end
        
        function audio_signal = istft(audio_stft,window_function,step_length)
            % Inverse Short-Time Fourier Transform (ISTFT)
            %   Here is some help text for this method.
            %
            %   See also ifft, stft
            
            % Number of time frames
            [~,number_times] = size(audio_stft);
            
            % Window length in samples
            window_length = length(window_function);
            
            % Number of samples for the signal
            number_samples = (number_times-1)*step_length+window_length;
            
            % Initialize the signal
            audio_signal = zeros(number_samples,1);
            
            % Inverse Fourier transform of the frames and real part to
            % ensure real values
            audio_stft = real(ifft(audio_stft));
            
            % Loop over the time frames
            for time_index = 1:number_times
                
                % Inverse Fourier transform of the signal (normalized
                % overlap-add if proper window and step)
                sample_index = step_length*(time_index-1);
                audio_signal(1+sample_index:window_length+sample_index) ...
                    = audio_signal(1+sample_index:window_length+sample_index)+audio_stft(:,time_index);
            end
            
            % Remove the zero-padding at the start and the end
            audio_signal = audio_signal(window_length-step_length+1:number_samples-(window_length-step_length));
            
            % Un-window the signal (just in case)
            audio_signal = audio_signal/sum(window_function(1:step_length:window_length));
            
        end
        
        function audio_mfcc = mfcc(audio_signal,sample_rate,number_filters,number_coefficients)
            % Mel Frequency Cepstrum Coefficients (MFFCs)
            %
            
            % Compute the audio spectrogram
            window_length = 2^nextpow2(0.04*sample_rate);
            window_function = hamming(window_length,'periodic');
            step_length = window_length/2;
            audio_spectrogram = spectrogram(audio_signal,window_function,step_length);  % Matlab's spectrogram
            audio_spectrogram = abs(audio_spectrogram(2:end,:));                        % Remove the DC component and take magnitude value
            
            % Compute the start indices of the triangular filters
            mininum_melfrequency = frq2mel(sample_rate/window_length);                          % Minimum mel frequency value in Hz
            maximum_melfrequency = frq2mel(sample_rate/2);                                      % Maximum mel frequency value in Hz
            filter_width = 2*(maximum_melfrequency-mininum_melfrequency)/(number_filters+1);	% Width of a triangular filter in the mel scale
            filter_indices = mininum_melfrequency:filter_width/2:maximum_melfrequency;          % Start (and end) indices of the triangular filters (linearly spaced in the mel scale)
            filter_indices = round(mel2frq(filter_indices)*window_length/sample_rate);          % Start (and end) indices of the triangular filters (logarithmically spaced in the linear scale)
            
            % Compute the MFCCs
            filter_bank = zeros(number_filters,window_length/2);                                      % Filter bank
            for filter_index = 1:number_filters                                                     % Loop over the filters
                filter_bank(filter_index,filter_indices(filter_index):filter_indices(filter_index+1)) ...
                    = linspace(0,1,filter_indices(filter_index+1)-filter_indices(filter_index)+1);    % Left side of the triangle filter (linspace gives more rigorous results than triang!)
                filter_bank(filter_index,filter_indices(filter_index+1):filter_indices(filter_index+2)) ...
                    = linspace(1,0,filter_indices(filter_index+2)-filter_indices(filter_index+1)+1);  % Right side of the triangle filter
            end
            audio_mfcc = dct(log(filter_bank*audio_spectrogram));                                   % Discrete Cosine Transform of the log of the magnitude spectrogram mapped onto the melscale using the filter bank
            audio_mfcc = audio_mfcc(2:number_coefficients+1,:);                                     % The first coefficients (not including the 0th) represent the MFCCs
            
        end
        
        function melfrequency_value = frq2mel(frequency_value)
            
            melfrequency_value = 2595*log10(1+frequency_value/700);
            
        end
        
        function frequency_value = mel2frq(melfrequency_value)
            
            frequency_value = 700*(10.^(melfrequency_value/2595)-1);
            
        end
        
        
        function cqt_kernel = kernel(sample_rate,frequency_resolution,minimum_frequency,maximum_frequency)
            
            % Number of frequency channels per octave
            octave_resolution = 12*frequency_resolution;
            
            % (constant) ratio of frequency to resolution (= fk/(fk+1-fk))
            quality_factor = 1/(2^(1/octave_resolution)-1);
            
            % Number of frequency channels for the CQT
            number_frequencies = round(octave_resolution*log2(maximum_frequency/minimum_frequency));
            
            % Window length for the FFT (= window length for the mininim frequency = longuest window)
            fft_length = 2^nextpow2(quality_factor*sample_rate/minimum_frequency);
            
            % Initialize the CQT kernel
            cqt_kernel = zeros(number_frequencies,fft_length);

            % Loop over the frequency channels
            for frequency_index = 1:number_frequencies
                
                % Frequency value (in Hz)
                frequency_value = minimum_frequency*2^((frequency_index-1)/octave_resolution);
                
                % Window length (nearest odd value for symmetry, in samples)
                window_length = 2*round(quality_factor*sample_rate/frequency_value/2)+1;
                
                % Temporal kernel (symmetric)
                temporal_kernel = hamming(window_length,'symmetric')' ... 
                    .*exp(2*pi*1j*quality_factor*(-(window_length-1)/2:(window_length-1)/2)/window_length)/window_length;
                
                % Pre zero-padding to center FFT (FFT does post zero-padding)
                temporal_kernel = cat(2,zeros(1,ceil((fft_length-window_length)/2)),temporal_kernel);
                
                % Spectral kernel (mostly real)
                spectral_kernel = fft(temporal_kernel,fft_length);
                
                % Make the spectral kernel sparser
                spectral_kernel(abs(spectral_kernel)<0.01) = 0;
                
                % Save the spectral kernels
                cqt_kernel(frequency_index,:) = spectral_kernel;
            end
            
            % Make the CQT kernel sparse
            cqt_kernel = sparse(cqt_kernel);
            
            % From Parseval's theorem
            cqt_kernel = conj(cqt_kernel)/fft_length;
            
        end
        
        function audio_spectrogram = spectrogram(audio_signal,sample_rate,time_resolution,cqt_kernel)
            
            % Number of time samples per time frame
            step_length = round(sample_rate/time_resolution);
            
            % Number of time frames
            number_times = floor(length(audio_signal)/step_length);
            
            % Number of frequency channels and FFT length
            [number_frequencies,fft_length] = size(cqt_kernel);
            
            % Zero-padding to center the CQT
            audio_signal = [zeros(ceil((fft_length-step_length)/2),1);audio_signal;zeros(floor((fft_length-step_length)/2),1)];
            
            % Initialize the spectrogram
            audio_spectrogram = zeros(number_frequencies,number_times);
            
            % Loop over the time frames
            for time_index = 1:number_times
                
                % CQT with kernel (magnitude)
                audio_spectrogram(:,time_index) = abs(cqt_kernel*fft(audio_signal((1:fft_length)+step_length*(time_index-1))));
            end
            
        end
        
        function audio_chromagram = chromagram(audio_signal,sample_rate,time_resolution,frequency_resolution,cqt_kernel)
            
            % CQT spectrogram
            audio_spectrogram = cqt.spectrogram(audio_signal,sample_rate,time_resolution,cqt_kernel);
            
            % Number of frequency channels and time frames
            [number_frequencies,number_times] = size(audio_spectrogram);
            
            % Number of chroma bins
            number_chromas = 12*frequency_resolution;
            
            % Chromagram initialized
            audio_chromagram = zeros(number_chromas,number_times);
            
            % Loop over the chroma bins
            for chroma_index = 1:number_chromas
                
                % Sum the energy of the frequency channels for every chroma
                audio_chromagram(chroma_index,:) = sum(audio_spectrogram(chroma_index:number_chromas:number_frequencies,:));
            end
        end
        
        
    end
    
end
