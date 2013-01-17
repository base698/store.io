express = require('express')
app = express()
app.use(express.static(__dirname))
port = 1337
console.log("Listening on port #{port}")
app.listen(port)

app.get '/',(req,res)->
	res.redirect '/test/index.html'
