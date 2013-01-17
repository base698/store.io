WEB_DIR			= .
COFFEE         = ${WEB_DIR}/node_modules/coffee-script/bin/coffee

build: init 
	${COFFEE} -o dist/ -c src/

init:
	npm install

run: build
	${COFFEE} server/server.coffee 

