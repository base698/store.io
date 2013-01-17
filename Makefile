WEB_DIR			= .
COFFEE         = ${WEB_DIR}/node_modules/coffee-script/bin/coffee

build: 
	${COFFEE} -o dist/ -c src/

init: build

run: build
	${COFFEE} server/server.coffee 

