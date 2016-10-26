
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
	byte offset;
	mtype flag = Empty;
	mtype suc = Empty;	/* later: get rid of what not needed */
	mtype pre = Empty;
	byte flagSize;
	bool cue = false; 	/* flag to stop before next step */
	short barsPlayed
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

hidden byte crossfader = 0; /* 0 = A, 255 = B, A first according to master.id=1 */

/* for ltl's. false until a track was loaded */
bool onAir = false;

/* decks */
deck 	A, B;
short_deck	master;

/* for use in "functions" */
byte i;
bool b;

/* for debugging purposes or interest only */
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
			)		->	harmCounter++
		:: else 	-> 	skip
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
	X.offset = 0;
	X.flag = X.t.section[i];
	X.flagSize = X.t.sectionSize[i];
	i = 0;
	X.barsPlayed = 0
}

/* for use in adjust */
inline stepsLeftRoutine(X) {
	i = (X.flagSize /*+ X.t.sectionSize[X.position+1]*/ - X.offset)/stepSize; /* fix for two section trans, so it will only fade in */
	/* update crossfader */
	if
	:: (X.id == 0)/*A*/	-> crossfader = crossfader - crossfader/i
	:: else		  /*B*/ -> crossfader = crossfader + (255-crossfader)/i
	fi;
	/* update master.tempo */
	master.tempo = master.tempo + (X.t.BPM-master.tempo)/i;
	i = 0;/* i is stepsLeft */
}

/* 	crossfader + tempo align control
	!do this in a postprocessing step! */
inline adjust(X) {
	if
	:: (X.pre == Empty) -> 	stepsLeftRoutine(X);
							if
							:: (!A.playing || !B.playing) -> master.tempo = X.t.BPM
							:: else 					  -> skip
							fi
	:: else				-> 	skip
	fi
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
	:: d_step { (X.playing && X.position < X.t.nrSections && X.offset+stepSize == X.t.sectionSize[X.position])
				-> X.position++; X.offset = 0; X.flag = X.t.section[X.position]; X.suc = X.t.section[X.position+1];X.pre = X.t.section[X.position-1]; X.flagSize = X.t.sectionSize[X.position]; X.barsPlayed = X.barsPlayed+stepSize;
				   checkChorus(X); resetPre(Y);
				   printf ("      position=%d, offset=%d ", X.position, X.offset); printm(X.flag) }

	/* inc offset */
	:: d_step { (X.playing && X.offset+stepSize < X.t.sectionSize[X.position])
				-> X.offset = X.offset + stepSize; X.barsPlayed = X.barsPlayed+stepSize;
				   checkChorus(X); /*adjust(X);*/
				   printf ("      position=%d, offset=%d ", X.position, X.offset); printm(X.flag) }

	/* start deck in chosen section */
	:: d_step { (!X.playing && X.position != 0 && master.id != X.id && !played[X.t.id] && (!Y.playing || Y.position > (Y.t.nrSections/2)) ) /* Y.position differs as first comes deck A, then B but that's not so important */
				-> checkHarm(X.t);
				   X.playing = true; onAir = true; master.id = X.id; master.key = X.t.key; master.tempo = X.t.BPM; X.suc = X.t.section[X.position+1]; X.pre = Empty; X.barsPlayed = X.barsPlayed+stepSize;
				   checkChorus(X); /*adjust(X);*/ checkParallel(X, Y);
				   printf("start position=%d, offset=%d ", X.position, X.offset); printm(X.flag) }

	/* stay stopped */
	:: (!X.playing)
				-> printf("paused                                     ")

	/* final stop forcing outro */
	:: d_step { (X.playing && played[0] && X.position == X.t.nrSections && X.offset+stepSize+stepSize == X.t.sectionSize[X.position] && X.barsPlayed > minBarsPlayed)
				-> X.offset = X.offset + stepSize; X.cue = true; X.barsPlayed = X.barsPlayed+stepSize;
				   checkChorus(X);
				   printf("stop  position=%d, offset=%d ", X.position, X.offset); printm(X.flag) }

	/* stop deck after step */
	:: d_step { (X.playing && !played[0] && X.position > (X.t.nrSections/2) && X.offset+stepSize+stepSize == X.t.sectionSize[X.position] && X.barsPlayed > minBarsPlayed)
				-> X.offset = X.offset + stepSize; X.cue = true; X.barsPlayed = X.barsPlayed+stepSize;
				   checkChorus(X);
				   printf("stop  position=%d, offset=%d ", X.position, X.offset); printm(X.flag)}
	fi
}

/* implements harmonic key rules and max tempo difference (max not audible difference) */
inline fits(X,new) {
	(
		(!onAir ||  /* onAir -> */
			(	X.t.id != new.id && X.flag == Empty && !played[new.id] && (A.playing || B.playing)
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
							   }	/* later give it a possible (!) nr of tracks played to allow finish */
	:: else					-> skip
	fi;
	i = 0;
	if
	:: (b)  -> played[0] = true
	:: else	-> skip
	fi;
	b = false
}

inline checkChorus(X) {	/* !!! implies that exists chorus > 2*stepSize */
	if
	:: (X.flag == Chorus && X.offset == X.flagSize-stepSize-stepSize) -> played[X.t.id] = true; updatePlayed() /* -2xStepSize is a fix to get the mix end with outro, otherwise it can end with normal stop */
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
	:: d_step { (A.cue) -> A.playing = false; A.offset = 0; A.flagSize = 0; A.position = 0; A.pre = A.flag; A.flag = Empty; A.cue = false; crossfader = 255 }
	:: d_step { (B.cue) -> B.playing = false; B.offset = 0; B.flagSize = 0; B.position = 0; B.pre = B.flag; B.flag = Empty; B.cue = false; crossfader = 0 }

	/* next bar, if playing/stopped stay playing/stopped (except track over) */
	:: atomic {
				(!A.cue && !B.cue)
					->	step(A, B); printf(" - ");
			 		 	step(B, A); printf(" X: %d, BPM: %d, key: %d\n", crossfader, master.tempo, master.key);  /* X and BPM are the values after the played offset */
			 		 	stepCounter = stepCounter + 1
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
			<>([] (played[0] && !A.playing && !B.playing && harmValue >= harmonicMixing && parallelValue >= parallelTrans))

			/* mixing rules */
		&&	((!A.playing && !B.playing) U (A.flag==Intro && A.playing || B.flag==Intro && B.playing))
		&& 	(parallel -> ((onAir -> (A.playing || B.playing) ) U (played[0])))		/* this rule makes search for parallel mix faster */
		&&	[] 	(	(!A.t.vocal[A.position] || !B.t.vocal[B.position])
				 && (A.barsPlayed < maxBarsPlayed && B.barsPlayed < maxBarsPlayed)
				 &&	(A.flagSize == B.flagSize -> A.offset == B.offset)
				 && (A.playing && B.playing && A.flagSize != B.flagSize -> ((A.offset == 0 -> B.offset == 0 || (B.offset == B.flagSize-A.flagSize && endMatching)) && (B.offset == 0 -> A.offset == 0 || (A.offset == A.flagSize-B.flagSize && endMatching))))
				 &&	(A.playing && B.playing
						->	(	/* Outro mixing */
								B.flag == Outro && A.flag == Intro                     || A.flag == Outro && B.flag == Intro
							 || B.flag == Outro && A.flag == Bridge                    || A.flag == Outro && B.flag == Bridge
							 	/* Chorus with Intro */
							 || A.flag == Chorus && B.flag == Intro  && played[A.t.id] && A.flagSize == B.flagSize
							 || B.flag == Chorus && A.flag == Intro  && played[B.t.id] && A.flagSize == B.flagSize
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
				 &&	(A.flag == Outro && A.playing && !played[0]
				 		-> (B.flagSize < A.flagSize-A.offset -> !B.playing))
				 &&	(B.flag == Outro && B.playing && played[0]
						-> !A.playing)
				 &&	(B.flag == Outro && B.playing && !played[0]
				 		-> (A.flagSize < B.flagSize-B.offset -> !A.playing))
				)

	)}

/* 	for a solution type "./verify.sh model.pml [-mX]", then "./trace.sh"
	for a shortest solution type "./verify.sh" , "cc -DREACH -o pan pan.c" and "./pan -i -m500 -a". [ctrl]+[c] if no progress
	others: "cd Documents/Uni/BachelorThesis/Spin/", "spin -t model.pml", "spin -a -v  model.pml"
	for changes in library change nrTracks, hidden tracks, trackLibrary(ids!) and load */
/* end */