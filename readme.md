# Store.IO

Store.IO is a lightweight way to use local storage in multiple browsers.

##
Browsers supported:  Firefox, Chrome, Safari

## How to Install
    npm build 
	 copy `dist/local_store.js` to the directory you wish to use it.

## How to use

First, include the javascript file in your project:
```html
	<script src="path_to/local_store.js"></script>
```

```js
var LocalStore = get_store();
store = new LocalStore();
// Store data
store.store(key,value,function() {
	// data stored.
});

// Load Data
store.load(key,function(value) {
	// Do something with the value
});
```

Check test/index.html for simple use case.


