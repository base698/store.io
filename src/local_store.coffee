((window)->
	store_info = {}
	requestFileSystem = window.requestFileSystem || window.webkitRequestFileSystem
	openDatabase = window.openDatabase || window.webkitOpenDatabase
	indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB

	isFunction = (obj)->
		return typeof obj is 'function'

	QUOTA_SIZE = 1024*1024*1024*10
	class NoSerializer
		serialize:(str)->
			return str
		
		deserialize:(data)->
			return data

	class LocalStore
		constructor:(config={})->
			store_info.initialized = false
			@context = config.context or 'default_context'
			store_info.operation_queue = []

			switch config.serializer
				when 'none' then @serializer = new NoSerializer()
				else @serializer = new NoSerializer()

		enable:null

		store:null

		load:null

		has:null

		remove:null

	class FileLocalStore extends LocalStore
		constructor:(config)->
			super(config)
			@init()

		@size:QUOTA_SIZE

		init:(init_cb)->
			success_cb = (entry)->
				entry.createWriter (writer)->
					writer.onwriteend = (e)->
						init_cb 1
					writer.onerror = (e)->
						console.log 'error'
						init_cb 0
					blob = new Blob(['1'],{type:'text/plain'})
					writer.write blob

			initFs = (fs)->
				fs.root.getFile 'enabled.txt',{create:true},success_cb,(error)->
					webkitStorageInfo.requestQuota PERSISTENT, FileLocalStore.size,cb,(error)->
						throw "Denied webstorage request"

			requestFileSystem PERSISTENT,FileLocalStore.size,initFs,(error)->
				console.log 'error enabling'

		request_quota:(cb)->
			webkitStorageInfo.requestQuota PERSISTENT, FileLocalStore.size,cb,(error)->
				throw "Denied webstorage request"

		handle_error:(error,method,args)->
			switch error.code
				when 10 then @request_quota ()=>
					method.apply(null,args)
				else console.log 'error: ',error

		create_dir_from_context:(cb)->
			self = @
			ctx = @context
			requestFileSystem PERSISTENT, FileLocalStore.size,(fs)->
				success = (dirEntry)->
					cb(dirEntry)
				fs.root.getDirectory ctx, {create: true},success,(error)->
					self.handle_error error,self.create_dir_from_context,arguments

		get_file: (key,cb)->
			success_cb = (entry)->
				entry.file (file)->
					cb file

			ctx = @context
			initFs = (fs)->
				fs.root.getFile ctx+'/'+key,{create:true},success_cb,(err)->
					console.log 'get_file error',err
			
			@create_dir_from_context (dirEntry)->
				requestFileSystem PERSISTENT,FileLocalStore.size,initFs,(error)->
					console.log 'error enabling'

		get_writer: (key,cb)->
			success_cb = (entry)->
				entry.createWriter cb
			ctx = @context
			initFs = (fs)->
				fs.root.getFile ctx+'/'+key,{create:true},success_cb,()->
					console.log 'root getfile error',arguments

			@create_dir_from_context (dirEntry)->
				requestFileSystem PERSISTENT,FileLocalStore.size,initFs,(error)->
					console.log 'error enabling'

		# XXX: positive this can be better utilizing proper types etc
		store:(key,obj,cb)->
			serializer = @serializer
			@get_writer key,(writer)->
				writer.onwriteend = (e)->
					if isFunction cb
						cb(key)
				writer.onerror = (e)->
					console.log 'error',e
				writer.write new Blob([serializer.serialize(obj)])
				
		store_blob:(key,blob,cb)->
			serializer = @serializer
			@get_writer key,(writer)->
				writer.onwriteend = (e)->
					if isFunction cb
						cb(key)
				writer.onerror = (e)->
					console.log 'error',e
				writer.write blob

		load_blob:(key,cb)->
			serializer = @serializer
			@get_file key,(file)->
				reader = new FileReader()
				reader.onloadend = (e)->
					cb(this.result)
				reader.onerror = (e)->
					console.log 'error'

				reader.readAsArrayBuffer(file)
			
		load:(key,cb)->
			serializer = @serializer
			@get_file key,(file)->
				reader = new FileReader()
				reader.onloadend = (e)->
					cb(serializer.deserialize(this.result))
				reader.onerror = (e)->
					console.log 'error'

				reader.readAsText(file)

		remove:(key,cb)->
			@get_file key,(file)->
				file.remove cb

		has:(key,cb)->
			ctx = @context
			success_cb = (entry)->
				cb(true)

			initFs = (fs)->
				fs.root.getFile ctx+'/'+key,{},success_cb,(error)->
					cb(false)

			requestFileSystem PERSISTENT,FileLocalStore.size,initFs,(error)->

	#TODO: use prepared statements
	class DatabaseLocalStore extends LocalStore
		constructor:(config)->
			super(config)

		init:(cb)->
			db = @db = openDatabase(@context, '1.0', 'Chromatik DB', 1024 * 1024 * 1024);
			db.transaction (tx)=>
				tx.executeSql("CREATE TABLE IF NOT EXISTS \"#{@context}\" (key,value BLOB)")
				if isFunction cb
					cb()

		enable:(cb)->
			@init cb

		store:(key,obj,cb)->
			@init ()=>
				@remove key,()=>
					@db.transaction (tx)=>
						sql = "INSERT INTO \"#{@context}\" (key,value) VALUES (\"#{key}\",\"#{obj}\")"
						tx.executeSql sql
						if isFunction cb then cb()

		load:(key,cb)->
			@init ()=>
				@db.transaction (tx)=>
					sql = "SELECT * FROM \"#{@context}\" WHERE key=\"#{key}\""
					tx.executeSql sql, [], (tx, results)->
						if results.rows.length is 0
							cb null
						else
							cb(results.rows.item(0).value)

		remove:(key,cb)->
			@init ()=>
				@db.transaction (tx) =>
					tx.executeSql "DELETE FROM \"#{@context}\" WHERE key=\"#{key}\"",[],()->
						if isFunction cb then cb()

		has:(key,cb)->
			self = @
			@load key,(results)->
				cb(results?)

	class IndexedDbLocalStore extends LocalStore
		constructor:(config)->
			super(config)
			@init()

		init:(init_cb)->
			request = indexedDB.open(@context,1);
			if @db then init_cb()

			self = @
			error_cb = ()->
				console.log 'error',arguments
			success_cb = (event)->
				self.initialized = store_info.initialized = true
				db = self.db = request.result

				if isFunction init_cb
					init_cb()

				self.execute_pending()

			request.onupgradeneeded = (event)=>
				self.db = db = event.target.result
				objectStore = db.createObjectStore(@context)

			request.onsuccess = success_cb

		enable:(cb)->
			if isFunction(cb) then cb()

		store:(key,obj,cb)->
			@init ()=>
				transaction = @db.transaction(@context,IDBTransaction.READ_WRITE)
				objectStore = transaction.objectStore(@context)
				request = objectStore.put(obj,key)
				request.onsuccess = (event)->
					cb(event.target.result)

		load:(key,cb)->
			
			@init ()=>
				transaction = @db.transaction(@context)
				objectStore = transaction.objectStore(@context)
				request = objectStore.get(key)
				request.onsuccess = (event)->
					if isFunction cb
						cb(request.result)

		remove:(key,cb)->
			@init ()=>
				transaction = @db.transaction(@context,'readwrite')
				objectStore = transaction.objectStore(@context)
				request = objectStore.delete(key)
				request.onsuccess = cb

		has:(key,cb)->
			@init ()=>
				@load key,(obj)->
					cb obj?

	get_store = () ->
		if requestFileSystem
			return FileLocalStore
		else if indexedDB
			return IndexedDbLocalStore
		else if openDatabase
			return DatabaseLocalStore
		else
			return null

	window.FileLocalStore = FileLocalStore
	window.DatabaseLocalStore = DatabaseLocalStore
	window.IndexedDbLocalStore = IndexedDbLocalStore
	window.get_store = get_store
)(window)	
