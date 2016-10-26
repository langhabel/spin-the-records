/* parameters */

/*<AUTOADD>*/

/*</AUTOADD>*/


#define endMatching false	/* additional to sections synched at offset 0 they might also be synched at last offset */

/* 	feed program not with library but with songs to play
	they have to be harmonically complete (a harmonic mix can be made out of them) and tempo align-able <- needs to be checked in advance,
	if not an error displays that you should disable harmonic mixing, also maxBarsPlayed might be too small*/

mtype = { Intro, Chorus, Bridge, Outro, Empty };	/* section types */

typedef track {
	byte id;
	byte key;	/* 1..12 ~> 1A..12A, 13..24 ~> 1B..12B */
	byte BPM;
	short duration; /* maybe needed to generate traktor markers*/
	short bars;
	byte nrSections;	/* -> maxSection = nrSections */
	mtype section[maxNrSections];
	byte sectionSize[maxNrSections];	/* in bars */
	bool vocal[maxNrSections] = false
};
typedef deck {
	bit id;	/* 0 = A, 1 = B */
	track t;
	byte position;		/* current section, always equivalent to flag */
	bool playing;		/* playing and position are reset in cue-handler, playing is true after step.start, position is set in load */
	mtype flag = Empty;
	mtype suc = Empty;	/* later: get rid of what not needed */
	mtype pre = Empty;
	byte flagSize;
	bool cue = false; 	/* flag to stop before next step */
	short barsPlayed;
	bool split = false	/* for split start */
};
typedef short_deck {
	bit id = 1; /* 0 = A, 1 = B to ensure alternating, def: the deck last started playing~> A first */
	byte key = 100;	/* for checkHarm such that first start contributes not to harm value*/
	byte tempo
}

/* tracks */

/*<AUTOADD>*/

/*</AUTOADD>*/



/* progress array */
bool played[nrTracks+1] = false;

/* no duplicate loading (for a cleaner counterexample path) */
bool loaded[nrTracks+1] = false;

/* for ltl's. false until a track was loaded */
bool onAir = false;

/* decks */
deck 	A, B;
short_deck	master;

/* temporal variables for use in "functions" */
byte i;
bool b;

/* not needed, for documenting purposes only */
hidden short stepCounter;

/* to keep record of # of harmonic transitions,in LTLs minimum value can be claimed*/
short harmValue = 0;
byte harmCounter = 0;

/* same for parallel transitions */
short parallelValue = 0;
byte parallelCounter = 0;

/* calculates new harmonic percentage if new and master are harmonic */
inline checkHarm(new) {
		if
		:: (   (!(new.key <= 12 && master.key <= 12 || new.key > 12 && master.key > 12)	/* !a || b replaces a->b */
				|| (   new.key%12 == (master.key+1)%12
					|| new.key%12 == (master.key-1)%12
					|| new.key%12 == (master.key+2)%12
					|| new.key    ==  master.key
				   )
			 	)
			&& (!(new.key <= 12 && master.key > 12)
				|| new.key == master.key-12
			   )
			&& (!(new.key > 12  && master.key <= 12)
				|| new.key == master.key+12
			   )
			)		->	harmCounter = harmCounter + 1
		:: else 	-> skip
		fi;
		if
		:: (nrTracks > 1)	->	harmValue = ((harmCounter) * 100)/(nrTracks-1)
		:: else				->	harmValue = 100
		fi
}

/* for setting parallelValue */
inline checkParallel(X, Y) {
	if
	:: (X.playing && Y.playing) -> 	parallelCounter++
	:: else 					-> 	skip
	fi;
	if
	:: (nrTracks > 1)	->	parallelValue = ((parallelCounter) * 100)/(nrTracks-1)
	:: else				->	parallelValue = 100
	fi
}

/* inline declarations */
inline load(X, new) {	/* non-det choice */
	X.t.id = new.id;
	X.t.key = new.key;
	X.t.BPM = new.BPM;
	X.t.duration = new.duration;
	X.t.bars = new.bars;
	X.t.nrSections = new.nrSections;
	for (i : 1 .. new.nrSections) {
		X.t.section[i] = new.section[i];
		X.t.sectionSize[i] = new.sectionSize[i];
		X.t.vocal[i] = new.vocal[i]
	};
	select(i: 1 .. X.t.nrSections/2);/* choose section */
	X.position = i;
	X.flag = X.t.section[i];
	X.flagSize = X.t.sectionSize[i];
	loaded[new.id] = true;
	i = 0;
	X.barsPlayed = 0
}

/* for LTL rule pre needs to be resetted */
inline resetPre(Y) {
	if
	:: (Y.playing)	->	skip
	:: else			->	Y.pre = Empty
	fi
}


/* next bar do... */
inline step(X,Y) {	/* non-det choice */
	if
	/* inc section */
	:: d_step { (!X.split  && X.playing && X.position < X.t.nrSections-1)
				-> X.position++; X.flag = X.t.section[X.position]; X.suc = X.t.section[X.position+1]; X.pre = X.t.section[X.position-1]; X.flagSize = X.t.sectionSize[X.position]; X.barsPlayed = X.barsPlayed+X.t.sectionSize[X.position];
				   checkChorus(X); resetPre(Y);
				   printf ("        position=%d=, size=%d= ", X.position, X.flagSize); printm(X.flag) }

	/* start deck in chosen section */
	:: d_step { (!X.playing && X.position != 0 && master.id != X.id && !played[X.t.id] && (!Y.playing || Y.position > (Y.t.nrSections/2)) ) /* Y.position differs as first comes deck A, then B but that's not so important */
				-> checkHarm(X.t);
				   X.playing = true; onAir = true; master.id = X.id; master.key = X.t.key; master.tempo = X.t.BPM; X.suc = X.t.section[X.position+1]; X.pre = Empty; X.barsPlayed = X.barsPlayed+X.t.sectionSize[X.position];
				   checkChorus(X); checkParallel(X, Y);
				   printf("start position=%d= size=%d= ", X.position, X.flagSize); printm(X.flag) }

	/* half, quarter, ... flagSize to partition section into smaller ones -> optional section doubling */
	/* start deck in chosen section and split it */
	:: d_step { (!X.playing && X.position != 0 && master.id != X.id && !played[X.t.id] && (!Y.playing || Y.position > (Y.t.nrSections/2)) ) /* Y.position differs as first comes deck A, then B but that's not so important */
				-> checkHarm(X.t);
				   select(i: 1 .. 2); i = i*2; /* i in {2,4}, cause of d_step i=2 */; X.flagSize = X.t.sectionSize[X.position]/i; i = 0; X.t.sectionSize[X.position] = X.t.sectionSize[X.position]-X.flagSize;
				   X.playing = true; onAir = true; master.id = X.id; master.key = X.t.key; master.tempo = X.t.BPM; X.suc = X.t.section[X.position]; X.pre = Empty; X.barsPlayed = X.barsPlayed+X.flagSize;
				   checkChorus(X); checkParallel(X, Y);
				   printf("start position=%d= size=%d= ", X.position, X.flagSize); printm(X.flag);
				   X.split = true }

	:: d_step { (X.split)
				-> X.flag = X.t.section[X.position]; X.suc = X.t.section[X.position+1]; X.pre = X.t.section[X.position]; X.flagSize = X.t.sectionSize[X.position]; X.barsPlayed = X.barsPlayed+X.t.sectionSize[X.position];
				   printf ("        position=%d=, size=%d= ", X.position, X.flagSize); printm(X.flag);
				   X.split = false }

	/* stay stopped */
	:: (!X.playing)
				-> printf("paused                                                 ")

	/* stop deck after step */
	:: d_step { (X.playing && played[X.t.id] && X.position > (X.t.nrSections/2) && X.barsPlayed > minBarsPlayed)
				-> X.position++; X.flag = X.t.section[X.position]; X.suc = X.t.section[X.position+1];X.pre = X.t.section[X.position-1]; X.flagSize = X.t.sectionSize[X.position]; X.barsPlayed = X.barsPlayed+X.t.sectionSize[X.position];
				   checkChorus(X); resetPre(Y); X.cue = true;
				   printf("stop position=%d= size=%d= ", X.position, X.flagSize); printm(X.flag)}

	/* could add same optional split for stop as for start (a choice preStop that halves the section and sets a flag such that in next step only nowStop is possible) */
	fi
}

/* implements harmonic key rules and max tempo difference (max not audible difference) */
inline fits(X,new) {
	(
		(!onAir ||  /* onAir -> */
			(	X.t.id != new.id && X.flag == Empty && !played[new.id] && (A.playing || B.playing) && !loaded[new.id]
			 &&	new.BPM * 100 < master.tempo * (100+tempoDiff) && new.BPM * 100 > master.tempo * (100-tempoDiff)
			 && (!(harmonicMixing == 100)	/* harmonicMixing==100 -> */
			 					 ||    (!(new.key <= 12 && master.key <= 12 || new.key > 12 && master.key > 12)
										|| (   new.key%12 == (master.key+1)%12
											|| new.key%12 == (master.key-1)%12
											|| new.key%12 == (master.key+2)%12
											|| new.key    ==  master.key)
									   )
									&& (!(new.key <= 12 && master.key > 12)
										|| new.key == master.key-12
									   )
									&& (!(new.key > 12  && master.key <= 12)
										|| new.key == master.key+12
									   )
				)	/* 1..12 ~> 1A..12A, 13..24 ~> 1B..12B   possible: ±1,±(12),+2 */
			)
		)
	 && (onAir ||  /* !onAir -> */
			X.position == 0)
	)
}

inline updatePlayed() {
	b = true;
	if
	:: (!played[0]) -> for (i : 1 .. nrTracks) {
									if
									:: (played[i])  -> skip
									:: (!played[i]) -> b = false
									fi
							   }
	:: else					-> skip
	fi;
	i = 0;
	if
	:: (b)  -> played[0] = true
	:: else	-> skip
	fi;
	b = false
}

inline checkChorus(X) {
	if
	:: (X.flag == Chorus) -> played[X.t.id] = true; updatePlayed()
	:: else -> skip
	fi
}



active proctype main() {
	/* create track library */
	d_step {
		A.id = 0;
		B.id = 1;

/*<AUTOADD>*/

/*</AUTOADD>*/


	}

	do
	/* stop just lets deck play Empty, so we need to pause it afterwards (as otherwise last step would be Paused) */
	:: d_step { (A.cue) -> A.playing = false; A.flagSize = 0; A.position = 0; A.pre = A.flag; A.flag = Empty; A.cue = false}
	:: d_step { (B.cue) -> B.playing = false; B.flagSize = 0; B.position = 0; B.pre = B.flag; B.flag = Empty; B.cue = false}

	/* next bar, if playing/stopped stay playing/stopped (except track over) */
	:: atomic {
				(!A.cue && !B.cue)
					->	step(A, B); printf(" - ");
			 		 	step(B, A); printf("(%d, %d)\n", master.key, master.tempo); stepCounter++  /* X and BPM are the values after the played section */
			  }

	/* load new track */
	:: atomic {
			   (!A.cue && !B.cue)
				->
					if

/*<AUTOADD>*/

/*</AUTOADD>*/


					fi
			 }
	od
}



ltl {!(		/* all played */
			<>([] (played[0] && !A.playing && !B.playing && harmValue >= harmonicMixing && parallelValue >= parallelTrans && (A.pre == Outro || B.pre == Outro)))

			/* mixing rules */
		&&	((!A.playing && !B.playing) U (A.flag==Intro && A.playing || B.flag==Intro && B.playing))
		&& 	(parallel -> ((onAir -> (A.playing || B.playing) ) U (played[0])))		/* this rule makes search for parallel mix faster */
		&&	[] 	(	(!A.t.vocal[A.position] || !B.t.vocal[B.position])
				 && (A.barsPlayed < maxBarsPlayed && B.barsPlayed < maxBarsPlayed)
				 && (A.playing && B.playing
				 		->	( A.flagSize == B.flagSize && A.flagSize >= 8 )
				 	)
				 &&	(A.playing && B.playing
						->	(	/* Outro mixing */
								B.flag == Outro && A.flag == Intro                     || A.flag == Outro && B.flag == Intro
							 || B.flag == Outro && A.flag == Bridge                    || A.flag == Outro && B.flag == Bridge
							 	/* Chorus with Intro */
							 || A.flag == Chorus && B.flag == Intro  && played[A.t.id]
							 || B.flag == Chorus && A.flag == Intro  && played[B.t.id]
							 	/* Bridges synched */
							 || A.flag == Bridge && B.flag == Bridge && played[A.t.id] || B.flag == Bridge && A.flag == Bridge && played[B.t.id]
							)
					)
				/* no cuts in Intros and Chorus cut, none from Outros */
				 && (A.playing && !B.playing && B.t.id != 0 && !played[0] && !parallel
				 		->	(	A.flag != Intro
				 			 && B.pre != Outro
				 			 && (A.flag == Chorus -> B.pre == Chorus || B.pre == Empty) /* what we get is chorus->chorus, chorus->bridge, bridge->bridge */
				 			)
				 	)
				 && (B.playing && !A.playing && A.t.id != 0 && !played[0] && !parallel
				 		->	(	B.flag != Intro
				 			 && A.pre != Outro
				 			 && (B.flag == Chorus -> A.pre == Chorus || A.pre == Empty)
				 			)
				 	)
				 /* Outro Mixing disabler */
				 &&	(A.flag == Outro && A.playing && played[0]
						-> !B.playing)
				 &&	(B.flag == Outro && B.playing && played[0]
						-> !A.playing)
				)

	)}

/* 	for a solution type "./verify.sh model.pml [-mX]", then "./trace.sh"
	for a shortest solution type "./verify.sh" , "cc -DREACH -o pan pan.c" and "./pan -i -m500 -a". [ctrl]+[c] if no progress
	others: "cd Documents/Uni/BachelorThesis/Spin/", "spin -t model.pml", "spin -a -v  model.pml"
	for changes in library change nrTracks, hidden tracks, trackLibrary(ids!) and load */
/* end */