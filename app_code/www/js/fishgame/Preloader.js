FishGame.Preloader = function(game) {
    this.preloadBar = null;
    //this.titleText = null;
    this.ready = false;
    this.ionic_scope;
    this.isStudyParticipant;
};

FishGame.Preloader.prototype = {
	
	preload: function () {

		//console.log("Preloader: preload called"); 

		this.load.onLoadComplete.addOnce(this.onLoadComplete, this);

		this.preloadBar = this.add.sprite(this.world.centerX, this.world.centerY, 'preloaderBar');
		this.preloadBar.anchor.setTo(0.5, 0.5);
		this.load.setPreloadSprite(this.preloadBar);
        
        //---- both aquariums
        this.load.bitmapFont('eightbitwonder', 'fonts/eightbitwonder.png', 'fonts/eightbitwonder.fnt');
		this.load.json('fishpoints', 'js/fishpoints.json');//fish json, points

		//
		this.load.atlasJSONArray('clownfish', 'sprite/clownfish.png', 'sprite/clownfish.json');

		//
		this.load.image('fish_progress', 'sprite/fish_progress_s.png');

		
		//progress bar
		this.load.spritesheet('timer', 'sprite/timer.png', 150, 20);

		//reward
		this.load.image('ball', 'img/bubble256yay.png');
		this.load.image('gift', 'img/gift.png');

		//
		this.load.image('gameover', 'img/Fireworks.png');


		//this.load.atlasJSONArray('blackdiver', 'sprite/black-diver-sprite.png', 'sprite/black-diver-sprite.json');

		//
		//Returns a random integer between min (inclusive) and max (inclusive)
		//Using Math.round() will give you a non-uniform distribution!
		//
		var max = 8;
		var min = 1;
		var rand_num = Math.floor(Math.random() * (max - min + 1)) + min;
		console.log('img/pirate-' + rand_num + '.png');
		this.load.image('pirate', 'img/pirate-' + rand_num + '.png');

		var	username = window.localStorage['username'] || 'unknown';
        this.isStudyParticipant = username.indexOf('-study-') !== -1; // !== -1;
        //-- this.isStudyParticipant = true;
        //-- 
        //this.ionic_scope.total_points = 900;  
		if((this.ionic_scope.total_days > 30) && this.isStudyParticipant){
            this.loadGameover();
        }else{
        	if(this.ionic_scope.total_points <1060){
				this.loadFishBowl();
        	}else{
        		this.loadSea();
        	}
        }


		//--- RedBanner.png
		//this.load.atlasJSONArray('banner', 'sprite/RedBanner.png', 'sprite/RedBanner.json');
		this.load.image('banner', 'img/RedBanner.png');
		this.load.image('banner_fish', 'img/banner_fish.png');


		//----
		var next_fish = window.localStorage['next_fish'] || 'img/aquarium_grey/clownfish.png';
		//next_fish = 'img/aquarium_grey/clownfish.png';
		console.log("Next fish: " + next_fish);
		this.load.image('clownfish_grey', next_fish);

		/*
		this.load.image('pouch', 'img/pouch.png');
		this.load.image('full_money', 'img/full_money.png');
		this.load.image('empty_money', 'img/empty_money.png');
		*/
		this.load.image('diamond', 'img/diamond.png');


		//start loading
		//this.load.start();

		var progressDisplay = 0;
		var timerEvt = this.time.events.loop(100, function (){
            if(this.load.progress < 100){
            	progressDisplay++;
                console.log('loading... '+(this.load.progress)+'%' + "; " + (100*progressDisplay));
            }else{
                //loadingText.text = 'Ready, Go!';
                console.log('Ready, Go!');
                this.time.events.remove(timerEvt);
            }

        }, this);
		 
		
	},

	create: function () {
		console.log("Preloader: create called");
		this.preloadBar.cropEnabled = false;
		//this.load.image('treasuresea', 'img/treasuresea.png');
        //this.load.atlasJSONArray('greencrab', 'sprite/greencrab.png', 'sprite/greencrab.json');
		//this.load.atlasJSONArray('angryfish', 'sprite/angryfish.png', 'sprite/angryfish.json');
		//this.load.atlasJSONArray('swordfish', 'sprite/swordfish.png', 'sprite/swordfish.json');
		//this.load.start();
	},

	assignscope: function(scope) {
        this.ionic_scope = scope;
    },

    //this is how to handle progress bar 
    //--- See on file complete http://technotip.com/4897/progress-bar-phaser/

	update: function () {

		//
		console.log("Preloader: update called");

		//this.cache.isSoundDecoded('game_audio') && 
        if(this.ready == true) {
            //this.ionic_scope.total_points = 1650;  	

            console.log("Days: " + this.ionic_scope.total_days + ", isStudyParticipant: " + this.isStudyParticipant);
            if((this.ionic_scope.total_days > 30) && this.isStudyParticipant){
            	this.state.start('Gameover');
            }else{
	            if(this.ionic_scope.total_points <770){
	            	this.state.start('GameSmall');
	            	this.ionic_scope.current_level = 'GameSmall';
	            	console.log("post loading sea");
	            	//this.loadSea();
	            	//this.load.start();
	            }


	            if(this.ionic_scope.total_points >=770 && this.ionic_scope.total_points <1060){
	            	this.state.start('Game');
	            	this.ionic_scope.current_level = 'Game';
	            	console.log("post loading sea");
	            	//this.loadSea();
	            	//this.load.start();
	            }


	            if(this.ionic_scope.total_points >=1060 && this.ionic_scope.total_points <1710){
	            	this.state.start('Level1Small');
	            	this.ionic_scope.current_level = 'Level1Small';
	            	console.log("post loading fishbowl");
	            	this.loadFishBowl();
	            	this.load.start();
	            }

	            if(this.ionic_scope.total_points >=1710){
					this.state.start('Level1');
					//this.state.start('Gameover');
					//this.state.start('Gamelast');
	            	this.ionic_scope.current_level = 'Level1';
	            	console.log("post loading fishbowl");
	            	this.loadFishBowl();
	            	this.load.start();
	            }
	        }

            //this.state.start('Game');
            //this.state.start('Level1');
            //this.state.start('Level1Small');
        }
	},

	onLoadComplete: function () {
	    console.log("Load complete");
	    this.ready = true;
	},

	loadFishBowl: function () {
		this.load.image('titlescreen', 'img/TitleBG4.png');    	
        this.load.image('journal', 'img/fishjournal.png');
        

        
        this.load.image('fish', 'img/fish.png');
		this.load.image('treasure', 'img/treasure.png');
		this.load.atlasXML('octopus', 'sprite/octopus.png', 'sprite/octopus.xml');
		this.load.atlasXML('seacreatures', 'sprite/seacreatures.png', 'sprite/seacreatures.xml');
		this.load.atlasJSONArray('greenfish', 'sprite/swimrightgreenfish.png', 'sprite/swimrightgreenfish.json');
		this.load.atlasJSONArray('seahorseyellow', 'sprite/seahorseyellow.png', 'sprite/seahorseyellow.json');
		this.load.atlasJSONArray('squid', 'sprite/squid.png', 'sprite/squid.json');
		this.load.atlasJSONArray('goldfish', 'sprite/goldfish.png', 'sprite/goldfish.json');
		this.load.atlasJSONArray('angelfish', 'sprite/angelfish.png', 'sprite/angelfish.json');
		this.load.atlasJSONArray('discusfish', 'sprite/discusfish.png', 'sprite/discusfish.json');
		this.load.atlasJSONArray('bettafish', 'sprite/betta.png', 'sprite/betta.json');
		//this.load.atlasJSONArray('guppy', 'sprite/guppy.png', 'sprite/guppy.json');
		this.load.atlasJSONArray('puffer', 'sprite/pufferfish.png', 'sprite/pufferfish.json');
		this.load.atlasJSONArray('tigerbarb', 'sprite/tigerbarb.png', 'sprite/tigerbarb.json');
		this.load.atlasJSONArray('butterfly', 'sprite/butterfly.png', 'sprite/butterfly.json');

		this.load.spritesheet('greenstarfish', 'sprite/greenstarfish.png', 512, 512, 3);
		this.load.spritesheet('redstarfish', 'sprite/redstarfish.png', 512, 512, 3);
		this.load.spritesheet('bluestarfish', 'sprite/bluestarfish.png', 512, 512, 3);

		//divers
		this.load.atlasJSONArray('purplediver', 'sprite/purple-diver-sprite.png', 'sprite/purple-diver-sprite.json');
		this.load.atlasJSONArray('blackdiver', 'sprite/black-diver-sprite.png', 'sprite/black-diver-sprite.json');
		this.load.atlasJSONArray('fatdiver', 'sprite/fat_swimmer.png', 'sprite/fat_swimmer.json');
		
		//
		this.load.image('smiley', 'img/smiley.png');
		this.load.image('diver', 'img/diver-0.png');
		this.load.image('fatdiver2', 'img/fatdiver2.png');

		

	},

	loadSea: function () {
		//this.load.audio('game_audio', 'audio/poop.mp3');

        //second aquarium
        //-- fish_journal
        this.load.image('fish_journal', 'img/fish_journal.png');

         //--- sea
        this.load.image('undersea', 'img/underwaterbr.jpg');
        this.load.image('treasuresea', 'img/treasuresea.png');
        this.load.image('coral', 'img/seabed.png');
        this.load.atlasJSONArray('sharkswim', 'sprite/sharkswimming.png', 'sprite/sharkswimming.json');
        this.load.atlasJSONArray('nemo', 'sprite/clownfish.png', 'sprite/clownfish.json');
		this.load.atlasJSONArray('dori', 'sprite/dory2.png', 'sprite/dory2.json');
		this.load.atlasJSONArray('jellyfish', 'sprite/jellyfish.png', 'sprite/jellyfish.json');
		this.load.atlasJSONArray('redcrab', 'sprite/redcrab.png', 'sprite/redcrab.json');
		this.load.atlasJSONArray('greencrab', 'sprite/greencrab.png', 'sprite/greencrab.json');
		this.load.atlasJSONArray('angryfish', 'sprite/angryfish.png', 'sprite/angryfish.json');
		this.load.atlasJSONArray('swordfish', 'sprite/swordfish.png', 'sprite/swordfish.json');
		this.load.atlasJSONArray('salmon', 'sprite/salmon.png', 'sprite/salmon.json');
		this.load.atlasJSONArray('yellowtang', 'sprite/yellowtang.png', 'sprite/yellowtang.json');
		this.load.atlasJSONArray('dolphin', 'sprite/dolphin.png', 'sprite/dolphin.json');
		this.load.atlasJSONArray('kitefish', 'sprite/kitefish.png', 'sprite/kitefish.json');
		this.load.atlasJSONArray('whale', 'sprite/whale.png', 'sprite/whale.json');
		this.load.spritesheet('blueanchovy', 'sprite/blueanchovy.png', 512, 125, 4);
		this.load.spritesheet('greenanchovy', 'sprite/greenanchovy.png', 512, 125, 4);
		this.load.spritesheet('pinkanchovy', 'sprite/pinkanchovy.png', 512, 125, 4);

		
		//
		this.load.image('gotosea', 'img/gotosea.png');

		//first_aq
		this.load.image('first_aq', 'img/first_aq.png');

		

		//submarine
		this.load.atlasJSONArray('submarine', 'sprite/submarine.png', 'sprite/submarine.json');
		this.load.atlasJSONArray('submarine_at', 'sprite/submarine_at.png', 'sprite/submarine_at.json');

		//this.preloadBar.destroy();

	},

	loadGameover: function(){
		//
		//this.load.image('gameover', 'img/Fireworks.png');
	}
};