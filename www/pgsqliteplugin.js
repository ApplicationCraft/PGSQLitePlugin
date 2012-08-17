(function(gap) {

 	var isIOS = (/iPhone|iPad|iPod/.test( navigator.platform ) && navigator.userAgent.indexOf( "AppleWebKit" ) > -1 );
 	if (!isIOS){
 		return;
 	}
 
	var callbacks, counter, root;
	root = this;
	callbacks = {};
	counter = 0;
	
	root.PGSQLitePlugin = (function() {
		PGSQLitePlugin.prototype.openDBs = {};
		
		function PGSQLitePlugin(dbPath, openSuccess, openError, options) {		   
			this.dbPath = dbPath;
			this.openSuccess = openSuccess;
			this.openError = openError;
			if (!dbPath) {
				throw new Error("Cannot create a PGSQLitePlugin instance without a dbPath");
			}
			
			this.openSuccess || (this.openSuccess = function() {
				console.log("DB opened: " + dbPath);
			});
			
			this.openError || (this.openError = function(e) {
				console.log(e.message);
			});
			
			this.open(this.openSuccess, this.openError, options);
		}
		
		PGSQLitePlugin.prototype.executeSql = function(sql, success, error) {
			if (!sql) throw new Error("Cannot executeSql without a query");
 		    return gap.exec(success, error, 'PGSQLitePlugin', 'backgroundExecuteSql', [this.dbPath, [].concat(sql || [])]);
		};
		
		PGSQLitePlugin.prototype.transaction = function(fn, success, error) {
			try{
				var t;
				t = new root.PGSQLitePluginTransaction(this.dbPath, this);
				fn(t);
				return t.complete(success, error);
			}
      		catch(er){
      			if (error) error(er);
      		}
		};
		
		PGSQLitePlugin.prototype.insert = function(table, values, success, error, compile) {
			var aSql = [];
			var sql = "INSERT INTO " + table + " (";
			var sql1 = "("; 
			for (var i in values){
				sql1 += " ?,";
				sql += i + ",";
				aSql.push( values[i] );
			} 
			sql = sql.substring(0, sql.length - 1) + ") VALUES ";
			sql1 = sql1.substring(0, sql1.length - 1) + ")";
			sql += sql1;
			aSql.unshift(sql);            
			if (compile == true){
				return aSql 
			}
			else{
				this.executeSql(aSql, function(res){ if (success)success(res.insertId); }, error);
			}
		};
		
		PGSQLitePlugin.prototype.del = function(table, where, whereArgs, success, error, compile) {
			var sql = "DELETE FROM " + table;
			if (where){
				sql += " WHERE " + where;
			}
			var aSql = [];
			aSql.push(sql);
			if (whereArgs){
				aSql = aSql.concat(whereArgs);
			}
			if (compile == true){
				return aSql;
			}
			else{
				this.executeSql(aSql, function(res){if (success)success(res.rowsAffected); }, error);
			}
		};
		
		PGSQLitePlugin.prototype.update = function(table, values, where, whereArgs, success, error, compile) {
			var sql = "UPDATE " + table + " SET ";
			var aSql = [];
			for (var i in values){
				sql += i + " = ? ,";
				aSql.push( values[i] );
			}
			sql = sql.substring(0, sql.length - 1) + " ";
			if (where){
				sql += " WHERE " +  where;
			}
			if (whereArgs instanceof Array){
				aSql = aSql.concat(whereArgs); 
			}
			aSql.unshift(sql);
			if (compile == true){
				return aSql;
			}
			else{
				this.executeSql(aSql, function(res){if (success)success(res.rowsAffected); }, error);
			}
		};
		
		PGSQLitePlugin.prototype.query = function(table, columns, where, whereArgs, groupBy, having, orderBy, limit, success, error, compile) {
			var sql = "SELECT ";
			var aSql = [];
			if (columns){
				for (var i in columns){
					sql += columns[i] + ",";
				}
				sql = sql.substring(0, sql.length - 1);
 			}
 			else {
 				sql += " * ";
 			}
 			sql += " FROM " + table + " ";
 			if (where){
 				if (whereArgs instanceof Array){
 					aSql = aSql.concat(whereArgs);
 				}
 				sql += " WHERE " + where;
 			}
 			if (groupBy){
 				sql += " GROUP BY " + groupBy + " ";
 			}
 			if (having){
 				sql += " HAVING " + having + " ";
 			}
 			if (orderBy){
 				sql += " ORDER BY " + orderBy + " ";
 			}
 			if (limit){
 				sql += " LIMIT " + limit + " ";
 			}
 			aSql.unshift(sql);
 			if (compile == true){
 				return aSql;
 			}
 			else{
 				this.executeSql(aSql, success, error);
 			}
 		};
 		
 	PGSQLitePlugin.prototype.open = function(success, error, options) {
 		var self = this;
 		if (!(this.dbPath in this.openDBs)) {
 			this.openDBs[this.dbPath] = true;
		    return gap.exec(success, error, 'PGSQLitePlugin', 'open', [this.dbPath, options]);
 		}
		else {
			if (typeof success == "function"){
				return success(self.openDBs[self.dbPath].result, self.openDBs[self.dbPath].self);
			}
		}
 	};
 	
 	PGSQLitePlugin.prototype.close = function(success, error) {
 		if (this.dbPath in this.openDBs) {
 			delete this.openDBs[this.dbPath];
 			return gap.exec(success, error, 'PGSQLitePlugin', 'close', [this.dbPath]);
 		}
 		else {
 			if (typeof error == "function"){
 				error("DB not opened");
 			}
 		}
 	};
 	
 	PGSQLitePlugin.prototype.remove = function(dbName, success, error) {
    	PGSQLitePlugin.remove(dbName, success, error);
    };
 	
 	PGSQLitePlugin.remove = function(dbName, success, error) {			   
		delete PGSQLitePlugin.prototype.openDBs[dbName];
		return gap.exec(success, error, 'PGSQLitePlugin', 'remove', [dbName]);
 	};
 	
 	return PGSQLitePlugin;
									
						   
 })();
 
 root.PGSQLitePluginTransaction = (function() {
 	function PGSQLitePluginTransaction(dbPath, db) {
 		this.dbPath = dbPath;
 		this.executes = [];
 		this.db = db;
 	}
 	
 	PGSQLitePluginTransaction.prototype.executeSql = function(sql, success, error) {
 		this.executes.push([].concat(sql || []));
 	};
 		
 	PGSQLitePluginTransaction.prototype.insert = function(table, values, success, error) {
 		var sql = this.db.insert(table, values, undefined, undefined, true );
 		this.executes.push([].concat(sql || []));
 	};
 	
 	PGSQLitePluginTransaction.prototype.del = function(table, where, whereArgs, success, error) {
 		var sql = this.db.del(table, where, whereArgs, undefined, undefined, true );
 		this.executes.push([].concat(sql || []));
 	};
 	
 	PGSQLitePluginTransaction.prototype.query = function(table, columns, where, whereArgs, groupBy, having, orderBy, limit, success, error) {
 		var sql = this.db.query(table, columns, where, whereArgs, groupBy, having, orderBy, limit, undefined, undefined, true );
 		this.executes.push([].concat(sql || []));
 	};
 	
 	PGSQLitePluginTransaction.prototype.update = function(table, values, where, whereArgs, success, error) {
 		var sql = this.db.update(table, values, where, whereArgs, undefined, undefined, true );
 		this.executes.push([].concat(sql || []));
 	};
 	
 	PGSQLitePluginTransaction.prototype.complete = function(success, error) {
 		var executes = [ ["BEGIN;"] ].concat(this.executes).concat([ ["COMMIT;"] ] );
		gap.exec(success, error, 'PGSQLitePlugin', 'backgroundExecuteSqlBatch', [this.dbPath, executes]);
 		this.executes = [];
 	};
 	return PGSQLitePluginTransaction;
 })();
 
}).call(this, window.Cordova || window.PhoneGap || window.cordova);


(function(gap) {
  
	var isAndroid = (/android/gi).test(navigator.appVersion);
 	if (!isAndroid){
 		return;
 	}
	
  var root = this;
  
  root.PGSQLitePlugin = (function() {
	
	PGSQLitePlugin.prototype.openDBs = {};
    function PGSQLitePlugin(dbPath, success, error, options) {
      this.dbPath = dbPath;
      if (!dbPath) {
        throw new Error("Cannot create a PGSQLitePlugin instance without a dbPath");
      }
      this.open(success, error, options);
    }
    
    PGSQLitePlugin.prototype.open = function(success, error, options) {
    	var self = this;
 		if (!(this.dbPath in this.openDBs)) {
 			gap.exec(function(result){
				  self.openDBs[self.dbPath] = { self : self, result : result};
				  	if (typeof success == "function"){
				  		success(result, self);
				  	}
 			}, error, 'PGSQLitePlugin', 'open', [this.dbPath, options])
 		}
		else {
			if (typeof success == "function"){
				success(self.openDBs[self.dbPath].result, self.openDBs[self.dbPath].self);
			}
		}
    };
    
    PGSQLitePlugin.prototype.close = function(success, error) {
    	if (this.dbPath in this.openDBs) {
 			delete this.openDBs[this.dbPath];
      		return gap.exec(success, error, 'PGSQLitePlugin', 'close', [this.dbPath]);
      	}
    };
    
    PGSQLitePlugin.prototype.remove = function(dbName, success, error) {
    	PGSQLitePlugin.remove(dbName, success, error);
    };
    
    PGSQLitePlugin.prototype.executeSql = function(sql, success, error) {
      return gap.exec(success, error, 'PGSQLitePlugin', 'backgroundExecuteSql', [this.dbPath, sql]);
    };
    
    PGSQLitePlugin.prototype.insert = function(table, values, success, error) {
      	return gap.exec(success, error, 'PGSQLitePlugin', 'insert', [this.dbPath, table, values]);
    };
    
    PGSQLitePlugin.prototype.del = function(table, where, whereArgs, success, error) {
      	return gap.exec(success, error, 'PGSQLitePlugin', 'delete', [this.dbPath, table, where, whereArgs]);
    };
    
    PGSQLitePlugin.prototype.update = function(table, values, where, whereArgs, success, error) {
      	return gap.exec(success, error, 'PGSQLitePlugin', 'update', [this.dbPath, table, values, where, whereArgs]);
    };
    
    PGSQLitePlugin.prototype.query = function(table, columns, where, whereArgs, groupBy, having, orderBy, limit, success, error) {
      	return gap.exec(success, error, 'PGSQLitePlugin', 'query', [this.dbPath, table, columns, where, whereArgs, groupBy, having, orderBy, limit]);
    };

    PGSQLitePlugin.prototype.transaction = function(fn, success, error) {
      var t = new root.PGSQLitePluginTransaction(this.dbPath, this);
      try{
      	fn(t);
      	return t.complete(success, error);
      }
      catch(er){
      	if (error) error(er);
      }
    };
    
    PGSQLitePlugin.remove = function(dbName, success, error) {			   
		delete PGSQLitePlugin.prototype.openDBs[dbName];
		return gap.exec(success, error, 'PGSQLitePlugin', 'remove', [dbName]);
 	};
    
    return PGSQLitePlugin;
  })();
  
  root.PGSQLitePluginTransaction = (function() {
    function PGSQLitePluginTransaction(dbPath, db) {
      this.dbPath = dbPath;
      this.executes = [];
      this.db = db;
    }
    PGSQLitePluginTransaction.prototype.executeSql = function(sql) {
      this.executes.push( { opts : [sql], type : "raw" } );
    };
    PGSQLitePluginTransaction.prototype.insert = function(table, values) {
      this.executes.push({opts : [table, values]  , type : "insert"});
    };
    PGSQLitePluginTransaction.prototype.del = function(table, where, whereArgs) {
      this.executes.push({opts : [table, where, whereArgs], type : "del"});
    };
    PGSQLitePluginTransaction.prototype.query = function(table, columns, where, whereArgs, groupBy, having, orderBy, limit) {
      this.executes.push({opts : [table, columns, where, whereArgs, groupBy, having, orderBy, limit], type : "query"});
    };
    PGSQLitePluginTransaction.prototype.update = function(table, values, where, whereArgs) {
      this.executes.push({opts : [table, values, where, whereArgs], type : "update"});
    };
    
    PGSQLitePluginTransaction.prototype.complete = function(success, error) {
      gap.exec(success, error, 'PGSQLitePlugin', 'transactionExecuteSqlBatch', [this.dbPath, this.executes]);
    };
    return PGSQLitePluginTransaction;
  })();

}).call(this, window.Cordova || window.PhoneGap || window.cordova);

function PGSQLiteHelper(){
	this.DATABASE_NAME = "test.db";
	this.DATABASE_VERSION = 1;
	this.DATABASE_STORAGE = "auto";
	this.db = null;
	this.CREATE_BATCH = [];
	this.UPDATE_BATCH = [];
	
	this.openDatabase = function(success, error, options){
		var __self = this;
		options = (typeof options == "object") ? options : {};
		options.storage = __self.DATABASE_STORAGE;
		__self.db = new PGSQLitePlugin(__self.DATABASE_NAME, function(result){
			var _version = __self.DATABASE_VERSION + "";
			if (result.status == 1){
				__self.onCreate(function(){
					__self.db.executeSql("PRAGMA user_version='"+_version + "'", function(res){
						if (typeof success == "function"){
							success( __self.db, _version, result.systemPath);
						}
					}, error);
				}, error);
			}
			else {
				if (result.version != _version){
					__self.onUpdate(result.version, function(){
						__self.db.executeSql("PRAGMA user_version='"+_version + "'" , function(res){
							if (typeof success == "function"){
								success( __self.db, _version, result.systemPath);
							}
						}, error);
					}, error);
				}
				else {
					if (typeof success == "function"){ 
						success( __self.db, _version, result.systemPath);
					}
				}
			}
		}, function(err){
			if (typeof error == "function"){
				error(err);
			}
		}, options );
		return this.db;
	}
	
	this.onCreate = function(success, error) {
		var ___self = this;
		___self.db.transaction(function(tr){
			for (var i in ___self.CREATE_BATCH){
				tr.executeSql(___self.CREATE_BATCH[i]);
			}
		}, success, error);
	}
	
	this.onUpdate = function(version, success, error) {
		var ___self = this;
		version = parseInt(version, 10) - 1;
		var currVersion = parseInt(this.DATABASE_VERSION, 10) - 1;
		if (version < 1){
			___self.onCreate(function(){
				___self.db.executeSql("PRAGMA user_version='"+ (currVersion + 1 ) + "'", function(res){
					if (typeof success == "function"){
						success( ___self.db, (currVersion + 1 ) + "");
					}
				}, error);
			}, error);
			return;
		}
		
		
		___self.db.transaction(function(tr){
			for (var j = version; j < currVersion; j++){ 
				for (var i in ___self.UPDATE_BATCH[j]){
					tr.executeSql(___self.UPDATE_BATCH[j][i]);
				}
			}
		}, success, error);
	}
	
	this.getDB = function(){
		return this.db;
	}
}