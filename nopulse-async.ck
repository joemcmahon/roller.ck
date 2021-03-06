int runLength;

// Pitchsets; note that the lower pitches are 
// duplicated to prevent low-interval clashes if
// we get all six layers at once.
[
	[ 108, 110, 112, 114, 117, 119],
	[ 96, 98, 100, 102, 105, 107],
	[ 84, 86, 88, 90, 93, 95 ],
	[ 72, 74, 76, 78, 81, 83 ],
	[ 54, 54, 54, 57, 59, 62],
	[ 36, 36, 47, 47, 50, 50]
] @=> int pitchSets[][];

fun int oneDsix() {
	return 1 + Math.random2(0,5);
}

fun int twoDsix() {
	return oneDsix() + oneDsix();
}

fun int[] permutesix() {
	int permutation[];
	[0, 1, 2, 3, 4, 5] @=>permutation;
	int i;
	for (0 => i; i < permutation.cap()-2; 1 +=> i) {
		int j;
		Math.random2(0, permutation.cap() - i - 1) => j;
		int t;
		permutation[i] => t;
		permutation[j] => permutation[i];
		t => permutation[j];
	}
	return permutation;
}

oneDsix() => runLength;;
<<< "Length: ", runLength >>>;

runLength * 60 => runLength;

int sections, sectionLength, layers;
;
twoDsix() => sections;;
runLength/sections => sectionLength;
<<< sections, " sections ", sectionLength, "seconds each" >>>;

while (runLength > 0) {
		<<< runLength >>>;
		// Check to see if we've switched sections. We should get a
		// section switch on the first time through the loop.
		if (runLength % sectionLength == 0) {
			// Start a new section. Calculate the number of voices, the notes they'll
			// play, and the start point and duration of each note. Spork each one off
			// to a new player, which will terminate when out of notes.
			<<< "Section ", sections >>>;
		 6 => layers;
			<<< layers, " layers this section" >>>;
			int rolls[];
			permutesix() @=> rolls;
      int i;
			for (1 => i; i < layers; 1 +=> i) {
				// generate notes and durations for this layer
				spork ~ playLayer(i, rolls[i]);
			}
		}
		1 -=> runLength;
		1::second +=> now;
}

fun void playLayer(int layerType, int pitchSet) {
	// each layer plays from 1 to 6 notes.
	// The notes are selected from one of six scales, chosen
	// by evaluating the global timestamp modulo 6, and the
	// specific note values and octave are determined by a
	// d6 roll. The sustain is chosen randomly as well, based
	// on the sectionLength. When this layer runs out of notes,
	// it exits.

	// Pick a random order to select the pitches from the pitchset with.
	time started;
	now => started;

	me.yield();
	int pitchIndices[];
	permutesix() @=> pitchIndices;

	// Pick a number of notes this layer will play.
	int totalNotes;
	6 => totalNotes;
	<<< started, "launched ", layerType >>>;

	// Select the notes from the predetermined pitchset.
	int notes[];
	[0, 0, 0, 0, 0, 0] @=> notes;
	int i;
	for ( 0 => i; i < totalNotes; 1 +=> i) {
		pitchSets[pitchSet][pitchIndices[i]] => notes[i];
		<<< "Note ", i, ": ", notes[i] >>>;
	}
	<<< "layer ", layerType, " starting" >>>;
	// Now we need to actually schedule and play the notes. We
	// have an interval in seconds, which we divide into sixths so
	// we line up prettily with the pulse. For each note, we need a
	// starting point, a duration, and an ending point. We want to
	// randomize all these as much as possible, but we don't want to
	// trail over the end of the section (exception: the last note can
	// trail over if it wants to).
	//
	// This will therefore be an optimization problem; we'll start by
	// choosing the point where we play the last note, and then insert
	// the rest of the notes we want to play going backward from there.
	// We have to allow at least 1/6 of a second for each note, as that's
	// the minimum duration, and we need to allow at least enough room for
	// all of the notes to fit. So we start at (the number of notes, the
	// maximum possible note slot) for the first start, and then work
	// backwards, decrementing the early point by 1 each time - each note
	// placed lets us have one more slot at the beginning for placements -
	// and reduce the maximum note slot to one slot before the latest note
	// placed. We continue until all the notes are placed. Since Math.random2()
	// supports the (lower, upper) directly, we just keep calling it with the
	// right parameters until we run out of notes.
	int schedule[][];
	[ 
	  // Start point, note, duration
		[ 0, 0, 0],
		[ 0, 0, 0],
		[ 0, 0, 0],
		[ 0, 0, 0],
		[ 0, 0, 0],
		[ 0, 0, 0]
	] @=> schedule;
	int unscheduledNotes;
	int lastSchedulePoint;
	sectionLength * 6 => lastSchedulePoint;
	for ( totalNotes-1 => i; i >= 0; 1 -=> i) {
		Math.random2(0, lastSchedulePoint) => lastSchedulePoint;;
		int duration;
		32 => duration;
		[lastSchedulePoint / 6, notes[i], duration] @=> schedule[i];
	}

	// Play the schedule, then exit.
	<<< started, "layer ", layerType, " ready" >>>;
	for (0 => i; i < totalNotes; 1 +=> i) {
		<<< "schedule ", i, schedule[i][0], schedule[i][1], schedule[i][2] >>>;
		playUnpulsed(started, i, schedule[i]);
	}
}

fun void playUnpulsed(time started, int i, int items[]) {
	<<< "playing unpulsed", started, i >>>;
	ModalBar modey => PRCRev r => Pan2 panner => Gain g => dac;
	0.75 => modey.gain;
	
  0.2 => r.mix;
	oneDsix() => modey.preset;
	(oneDsix()/3.0)-1.0  => panner.pan;
	<<< "start in ", items[0] >>>;
	items[0]::second +=> now;
	Std.mtof(items[1]) => modey.freq;
	Math.random2f( 0.2, 0.8 ) => modey.strikePosition;
	<<< "play ", items[1] >>>;
	1.0 => modey.strike;
	items[2]::second +=> now;
	<<< "played" >>>;
	me.exit();
}

// Make sure last note reverb trails off.
60::second => now;
