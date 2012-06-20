# SQLite plugin for Cordova

This is a prototype of a cross-platform SQLite Cordova plugin. Android
and iOS are currently supported

The goal is for a single JavaScript file to be usable on all supported
platforms, and the native code to be installed in a project through a [separate
script](http://github.com/alunny/pluginstall) (to install on iOS, you will need
pluginstall version 0.3.1 or above)

## The Structure

    plugin.xml
    -- src
      -- android
        -- PGSQLitePlugin.java
      -- ios
        -- PGSQLitePlugin.h
        -- PGSQLitePlugin.m
    -- www
      -- pgsqliteplugin.js

## plugin.xml

The plugin.xml file is loosely based on the W3C's Widget Config spec.

It is in XML to facilitate transfer of nodes from this cross platform manifest
to native XML manifests (AndroidManifest.xml, App-Info.plist, config.xml (BB)).

## PGSQLitePlugin JavaScript API

As with most Cordova/PhoneGap APIs, functionality is not available until the
`deviceready` event has fired on the document. The `pgsqliteplugin.js` file
should be included _after_ the `phonegap.js` file.

All functions are called on the created PGSQLitePlugin object: 

	var db = new PGSQLitePlugin(name, successOpenDatabaseFunction, errorOpenDatabaseFunction)


	name - database name
	successOpenDatabaseFunction - success callback function, return arguments:
	first argument - object: 
		obj.version - database version, 
		obj.status - number, 0 - database opened, 1 - database created, 2 - database created from resources
	second argument - db - database object
	errorOpenDatabaseFunction - error callback function
	
Example:
	
	var db = new PGSQLitePlugin("testdb.sqlite3", function(dbResult, dbObject){
		console.log("Database status=" + dbResult.status);
		console.log("Database version=" + dbResult.version);
		db = dbObject;
	}, function(err){
		console.log("Error create database::err=" + err);
	});

### Methods

#### open
    db.open(success, error)
	
Open database function

	success - success callback function
	error - error callback function

#### close
    db.close(success, error)

Close database function

	success - success callback function
	error - error callback function

#### remove
    PGSQLitePlugin.remove(dbName, success, error)

Remove database function

	dbName - database name
	success - success callback function
	error - error callback function, first argument - object: 
		obj.status - 0 - database not exist, otherwice - other erorr 
		obj.message - error message
	
Example:

	PGSQLitePlugin.remove("testdb.sqlite3", function(){
		console.log("database was removed");
	}, function(err){
		console.log("error remove database::err.message=" + err.message + "::err.status="+err.status);
	});

#### executeSql
	db.executeSql(sql, success, error)

Runs the provided SQL. If it is SELECT statment - return object `res = { rows : [ {key: value}, {key: value1}, {key: value1} ] }, where key is field name`

	sql - sql query
	success - success callback function
	error - error callback function

Example:

    db.executeSql("CREATE TABLE IF NOT EXISTS test (testID TEXT NOT NULL PRIMARY KEY, fio TEXT NOT NULL, adress TEXT)", function(){
		console.log( "table test was created" );
	}, function(err){
		console.log("error creating table test::" + err);
	});

#### insert
	db.insert(table, values, success, error)

Convenience method for inserting a row into the database.

	table  - the table to insert the row into
	values - this map contains the initial column values for the row. The keys should be the column names and the values the column values
	success - success callback function - first paramert the row ID of the newly inserted row
	error - error callback function

Example:

	db.insert("test", { id_user : 100, name : "Username" }, function(id){ 
		console.log("id="+id); 
	}, function(er){
		console.log("error="+er);
	});

#### update
	db.update(table, values, where, whereArgs, success, error)
	
Convenience method for updating rows in the database

	update(table, values, where, whereArgs, success, error)
	table  - the table to insert the row into
	values - a map from column names to new column values
	where - the optional WHERE clause to apply when updating. Passing null will update all rows.
	whereArgs - You may include ?s in where, which will be replaced by the values from whereArgs, in order that they appear in the where. The values will be bound as Strings.
	success - success callback function - first paramert the number of rows affected
	error - error callback function

Example:

	db.update("test", {name : "New Username" }, "id = ?", [1], function(count){ 
		console.log("count="+count); 
	}, function(er){
		console.log("error="+er);
	});

#### del
	db.del(table, where, whereArgs, success, error)

Convenience method for deleting rows in the database

	table  - the table to insert the row into
	where - the optional WHERE clause to apply when updating. Passing null will update all rows.
	whereArgs - You may include ?s in where, which will be replaced by the values from whereArgs, in order that they appear in the where. The values will be bound as Strings.
	success - success callback function - first paramert the number of rows affected
	error - error callback function

Example:

	db.del("test", "id = ?", ["1"], function(count){ 
		console.log("count="+count); 
	}, function(er){
		console.log("error="+er);
	});

#### query
	db.query(table, columns, where, whereArgs, groupBy, having, orderBy, limit, success, error)

Query the given table

	table  - the table to insert the row into
	columns - A list of which columns to return. Passing null will return all columns
	where - the optional WHERE clause to apply when updating. Passing null will update all rows.
	whereArgs - You may include ?s in where, which will be replaced by the values from whereArgs, in order that they appear in the where. The values will be bound as Strings.
	groupBy - A filter declaring how to group rows, formatted as an SQL GROUP BY clause (excluding the GROUP BY it__self__). Passing null will cause the rows to not be grouped.
	having - A filter declare which row groups to include in the cursor, if row grouping is being used, formatted as an SQL HAVING clause (excluding the HAVING it__self__).
	orderBy - How to order the rows, formatted as an SQL ORDER BY clause (excluding the ORDER BY it__self__). Passing null will use the default sort order, which may be unordered
	limit - Limits the number of rows returned by the query, formatted as LIMIT clause. Passing null denotes no LIMIT clause
	success - success callback function - first paramert return object res = { rows : [ {key: value}, {key: value1}, {key: value1} ] }, where key is field name
	error - error callback function
	
Example:

	db.query("test", ["id", "name"], "count > ?", [100], null, null, "name", null, function(res){ 
		for (var i in res.rows){ 
			for (var key in res.rows[i]){ 
				console.log(key + "=" + res.rows[i][key] ); 
			} 
		} 
	}, function(er){
		console.log("error="+er);
	});

#### transaction
	db.transaction(fn, success, error)

SQL transaction

	fn - transaction function
	success - success callback function
	error - error callback function

Example:

	db.transaction(function(tr){
		tr.executeSql("SELECT * FROM test");
		tr.update("test_table", {data_num : 999}, "id = ?", [1]);
		tr.insert("test_table", {data_num : 333});
		tr.executeSql("SELECT * FROM test_table WHERE id=1'");
	}, function(){
		console.log("transaction completed");
	}, function(){
		console.log("error transaction");
	});

## License

Apache
