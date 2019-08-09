s = Server.default;

s.options.numAnalogInChannels = 8;
s.options.numAnalogOutChannels = 8;
s.options.numDigitalChannels = 16;

s.options.blockSize = 128;
s.options.hardwareBufferSize = 128;

// This uses the Audio Expansion Capelet
s.options.numInputBusChannels = 10;
s.options.numOutputBusChannels = 10;
s.options.memSize = 32768;

// For controlling via the SCIDE
s.options.maxLogins = 4;

s.waitForBoot({

	// setup
	~mics = [0,1,3,4,5,6,7,8,9];
	~speakers = [0,1,2,3,4,5,8,9];

	~synths = nil ! ~speakers.size;

	Tdef(\main).stop;
	Tdef(\main, {
		inf.do {
			var scale = Scale.choose;
			var ifreq = rrand(500.0, 1000.0);
			SynthDef(\fdbkFollower, { |outBus=0, delayTime=0.1, gain=0.1|
				var snd, peak;
				var trig_choose_new_input = Impulse.kr(1/Rand(10.0, 20.0));
				var trig_choose_new_freqs = PulseDivider.kr(trig_choose_new_input, Rand(64, 128));
				var sndIn, sndInOld;
				var sndInBus1, sndInBusOld1;
				var resonator;
				
                // Chooses a random mic, delays the trigger by 1 frame so we sample and hold
                // the old value to do a fade/transition
				sndInBus1 = TChoose.kr(Delay1.kr(trig_choose_new_input), ~mics);
				sndInBusOld1 = Latch.kr(sndInBus1, trig_choose_new_input);

                // Do the fadeIn and fadeOut with envelopes
				sndIn = SoundIn.ar(sndInBus1) * EnvGen.ar(Env.new([0.000001, 1.0], [0.7], \exp), trig_choose_new_input);
				sndInOld = SoundIn.ar(sndInBusOld1) * EnvGen.ar(Env.new([1, 0.00000001], [0.9], \exp), trig_choose_new_input);

				snd = Mix.ar([sndIn, sndInOld]);
				snd = snd + DelayL.ar(snd*8, 5.0, delayTime.lag(3));

                // Pitch tracking for modulating the feedback
				peak = Pitch.kr(snd, downSample: 3);
				snd = MidEQ.ar(snd, peak[0].lag(Rand(0.2, 1.0)), 1, -24);

				resonator = DynKlank.ar(
					`[([ifreq, ifreq*2, ifreq*3, ifreq*4, ifreq*5]) * TChoose.kr(trig_choose_new_freqs, scale.ratios).lag(0.5) * TWChoose.kr(trig_choose_new_freqs, [0.125, 0.25, 0.5, 1, 1], [0.2, 0.2, 0.9, 0.6, 0.1].normalizeSum).lag(0.05),
						[1.0, 0.6, 0.8, 0.9, 0.3],
						[6, 5, 6, 2, 4]],
					snd*0.002);

				snd = snd + resonator;

                // Those values were choosen for the specific location of ACUD
				snd = Limiter.ar(snd, 0.4, 0.1);
				snd = LPF.ar(snd, LFNoise1.ar(1).range(3000, 6000));
				Out.ar(outBus , snd * gain.lag(4));
			}).add;

            // If there are any synths, set the gain to zero to fade for the next settings
			~speakers.do {|i|
				if (~synths[i] != nil, {
					~synths[i].set(\gain, 0);
				});
			};

			5.wait;

			~speakers.do {|i|
				var gain = 0.1;
                // The first two outputs use different amplifiers
				if (i < 2, { gain = 2.0 });
				~synths[i].free; ~synths[i] = Synth(\fdbkFollower, [\outBus, i, \delayTime, rrand(0.08, 4.0), \gain, gain]);
			};
			(60*rrand(15, 30)).wait;
		};
	}).play;
});
