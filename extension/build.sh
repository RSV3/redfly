cp manifest.json built
cp redfly.css built
cp *.png built
coffee -o built -c extconf.coffee
coffee -o built -c redflybackground.coffee
coffee -o built -c redflycontent.coffee
coffee -o built -c linkedcontent.coffee
