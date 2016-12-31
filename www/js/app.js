// Ionic Starter App

// angular.module is a global place for creating, registering and retrieving Angular modules
// 'starter' is the name of this angular module example (also set in a <body> attribute in index.html)
// the 2nd parameter is an array of 'requires'

//
//--- http://www.ng-newsletter.com/posts/building-games-with-angular.html
//

var app = angular.module('starter', ['ionic'])

app.run(function($ionicPlatform) {
  $ionicPlatform.ready(function() {
    if(window.cordova && window.cordova.plugins.Keyboard) {
      // Hide the accessory bar by default (remove this to show the accessory bar above the keyboard
      // for form inputs)
      cordova.plugins.Keyboard.hideKeyboardAccessoryBar(true);

      // Don't remove this line unless you know what you are doing. It stops the viewport
      // from snapping when text inputs are focused. Ionic handles this internally for
      // a much nicer keyboard experience.
      cordova.plugins.Keyboard.disableScroll(true);
    }
    if(window.StatusBar) {
      StatusBar.styleDefault();
    }
  });
})

app.directive("w3TestDirective", function() {
    return {
        restrict : "A",
        template : "<div id = 'gameArea'></div>",
        link : function(scope, element, attrs, injector){
            console.log("link function called");

            
            var game = new Phaser.Game(window.innerWidth, 500, Phaser.AUTO, 'gameArea');

            //game.input.touch.enabled = false;
            //game.input.mouse.enabled = false;

            //Phaser.Canvas.setTouchAction(game.canvas, "auto");
            //game.input.touch.preventDefault = false;

            game.state.add('Boot', FishGame.Boot);
            game.state.add('Preloader', FishGame.Preloader);
            game.state.add('StartMenu', FishGame.StartMenu);
            game.state.add('Game', FishGame.Game);
            game.state.start('Boot');
            
            /*
            //I want change a directive
            scaleRatio = window.devicePixelRatio / 3;

            //Create a new game instance and assign it to the 'gameArea' div

            //game = new Phaser.Game(window.innerWidth * window.devicePixelRatio, (window.innerHeight * window.devicePixelRatio) - 45 * window.devicePixelRatio, Phaser.AUTO, 'gameArea');
       
            var game = new Phaser.Game(window.innerWidth-20, 300, Phaser.AUTO, 'gameArea', { preload: preload, create: create });
       
            function preload () {
                  game.load.image('logo', 'img/ionic.png');
            }

            function create () {

                //
                var logo = game.add.sprite(game.world.centerX, game.world.centerY, 'logo');
                logo.anchor.setTo(0.5, 0.5);

                Phaser.Canvas.setTouchAction(game.canvas, "auto");
                game.input.touch.preventDefault = false;

                //
                scope.$emit('game:something', 'holla');  
            }
            */

            //create the game here


            /* --- If this goes from the game to ionic
            // See how to handle -- http://stackoverflow.com/questions/14502006/working-with-scope-emit-and-on
            var addNewPlayer = function(player) {
              players.push(player); // some player array holding all the players
              scope.$emit('game:newPlayer', player);
            }
            */

            /*
                // Set up the game
                // from "ionic" to "game" with "$injector".
                scope.$on('game:toggleMusic', function() {
                  Game.toggleMusic(); // some function that toggles the music
                });
            */

            //clown fish animation
            //-- http://www.sevenoaksart.co.uk/clownfish.htm
            //more fishes: http://www.sevenoaksart.co.uk/goldfish.htm
            //shark -- http://www.sevenoaksart.co.uk/shark.htm
            //dophins http://www.sevenoaksart.co.uk/dolphins.htm
            //Convert gif to imgaes "http://ezgif.com/split"

            scope.$on('game:test', function() {
                  //console.log(JSON.stringify(game, null, 4));
                  //call something like the follows
                  //-- Game.toggleMusic();

                  //add a fish.
                  //game.state.Game.test();
                  //game.state["Game"].test();
                  game.state.states["Game"].test();

            });



        }
    };
});


app.controller("MainCtrl", function($scope,$state) {
    $scope.startGame = function() {
      //console.log("came here");

      $scope.$broadcast('game:test');//SUCCESS

      // $state.go('game');

      //use the scope to do things?
    };

    $scope.$on('game:something', function(event, data) { 
      console.log("Got something: " + data); 
    });



});




