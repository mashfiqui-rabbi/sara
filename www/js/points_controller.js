
app.controller("PointsCtrl", function($scope, $location,$cordovaStatusbar,$http,$rootScope,saraDatafactory) {
    console.log($location.path() + ", " + $rootScope.total_points);

    

        //status bar color
    document.addEventListener("deviceready", onDeviceReady, false);
    function onDeviceReady() {
        console.log(StatusBar);
        if(ionic.Platform.isAndroid()){
          //$cordovaStatusbar.overlaysWebView(true);
          //$cordovaStatusbar.styleHex('#4527A0');
          if(window.StatusBar) {
            StatusBar.overlaysWebView(true);
            StatusBar.backgroundColorByHexString("#303F9F"); //Light
            //StatusBar.style(2); //Black, transulcent
            //StatusBar.style(3); //Black, opaque
          }
        }
    }

    /*
    saraDatafactory.pullBadgeData(function(returnValue) {
        // use the return value here instead of like a regular (non-evented) return value
        console.log("Badge value: " + returnValue);
        //window.localStorage['score_data'] = returnValue;
    });
    */


    //
    //all badges-- There is a record for the badges.
    var badges;
    if($rootScope.badges == undefined){
      //badges = JSON.parse(window.localStorage['badges'] || "{}");
      var cognito_data = JSON.parse(window.localStorage['cognito_data'] || "{}");
      badges = cognito_data['badges'];
      if('money' in badges){ //means things are empty.
      }else{
          badges['daily_survey'] = [0,0,0,0,0,0];
          badges['weekly_survey'] = [0,0,0,0];
          badges['active_tasks'] = [0,0,0,0,0,0];
          badges['money'] = 0;
      }
      $rootScope.badges = badges;
    }else{
      badges = $rootScope.badges;
    }

    //for demo
    /*
    $rootScope.total_score = 360;
    badges['daily_survey'] = [1,1,0,0,0,0];
    badges['weekly_survey'] = [0,0,0,0];
    badges['active_tasks'] = [1,1,0,0,0,0];
    badges['money'] = 3;
    */
    
    //
    $scope.amount_earned = "$" + badges['money'];




    //var current_points = 1000;
    var current_points = $rootScope.total_score;

    $http.get('js/fishpoints.json').success(function(data) {
      //console.log("Fishes: " + data);


      var survey_string = "";
      var isNextAvailableStillMasked = false;
      for(var i = 0; i < data.length; i++) {
          data[i].class = 'nonshade';
          data[i].img = data[i].img.substring(0, data[i].img.length-4) + '_tn.jpg';
          if(current_points < data[i].points){
            if(isNextAvailableStillMasked == false){
               //
               data[i].img = data[i].img.substring(0, data[i].img.length-7) + '-grey_tn.jpg';
               isNextAvailableStillMasked = true;
               //data[i].class = 'shade';
            }
            else{
              data[i].img = 'img/cryptocoin_tn.jpg';
            }
          }
      }
       
      $scope.pointsdata = data;


      //console.log("Fishes: " + JSON.stringify($scope.pointsdata));
      //$scope.$apply();
    });



    //decide which badges to show

    var demo_show_all_badges = false;

    //-------------- Active tasks
    //--------------
    //var active_tasks = [5,0,0,0,1,0];
    var active_tasks = badges['active_tasks'];
    var active_tasks_badges_img = ['img/badgeAT-none.png','img/badgeAT1.png','img/badgeAT2.png','img/badgeAT3.png','img/badgeAT4.png','img/badgeAT5.png','img/badgeAT6.png'];
    //we are doing this because the trophies do have the right size.
    var at_width = [39,45,41,45,43,45,43];

    $scope.active_tasks_badges = [];
    if(sum(active_tasks)  == 0){
        $scope.active_tasks_badges.push({"img": active_tasks_badges_img[0], "count": 0, "width": at_width[0]});
    }else{

        for(var i = 1; i < active_tasks_badges_img.length; i++){
          if(active_tasks[i-1] > 0)
            $scope.active_tasks_badges.push({"img": active_tasks_badges_img[i], "count": active_tasks[i-1], "width": at_width[i]});
        }

    }
    //console.log("Active tasks: " + JSON.stringify($scope.active_tasks_badges));


    var daily_survey_tasks = badges['daily_survey']; //[3,0,1,0,0,1]; 
    var ds_tasks_badges = ['img/backgroud_daily.png','img/green.png','img/blue.png','img/red.png','img/bronze.png','img/silver.png','img/gold.png'];
    $scope.daily_survey_badges = [];
    if(sum(daily_survey_tasks)  == 0){
        $scope.daily_survey_badges.push({"img": ds_tasks_badges[0], "count": 0, "width": 45});
    }else{

        for(var i = 1; i < ds_tasks_badges.length; i++){
          if(daily_survey_tasks[i-1] > 0)
            $scope.daily_survey_badges.push({"img": ds_tasks_badges[i], "count": daily_survey_tasks[i-1], "width": 45});
        }

    }


    var weekly_survey_tasks_count = sum(badges['weekly_survey']);  
    var ws_tasks_badges = ['img/trophy_background.png','img/green_trophy.png','img/bronze_trophy.png','img/silver_trophy.png','img/gold_trophy.png'];
    
    //
    $scope.weekly_survey_badges = [];
    if(weekly_survey_tasks_count == 0){
        $scope.weekly_survey_badges.push({"img": ws_tasks_badges[0], "count": 0, "width": 45});
    }
    if(badges['weekly_survey'][0]==1){
        $scope.weekly_survey_badges.push({"img": ws_tasks_badges[1], "count": 0, "width": 45});
    }
    if(badges['weekly_survey'][1]==1){
        $scope.weekly_survey_badges.push({"img": ws_tasks_badges[2], "count": 0, "width": 45});
    }
    if(badges['weekly_survey'][2]==1){
        $scope.weekly_survey_badges.push({"img": ws_tasks_badges[3], "count": 0, "width": 45});
    }
    if(badges['weekly_survey'][3]==1){
        $scope.weekly_survey_badges.push({"img": ws_tasks_badges[4], "count": 0, "width": 45});
    }



    $scope.goHome = function() {
        $location.path("/");
    };

    function sum(arr){
        var total=0;
        for(var i in arr){
          total += arr[i]; 
        }
        return total;
    }



});