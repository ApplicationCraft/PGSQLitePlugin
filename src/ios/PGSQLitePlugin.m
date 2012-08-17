#import "PGSQLitePlugin.h"

@implementation PGSQLitePlugin

@synthesize openDBs;
@synthesize appDocsPath;

-(CDVPlugin*) initWithWebView:(UIWebView*)theWebView
{
	self = (PGSQLitePlugin*)[super initWithWebView:theWebView];
	if (self) {
		openDBs = [NSMutableDictionary dictionaryWithCapacity:0];
		[openDBs retain];
		
		NSString* documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		[self setAppDocsPath:documents];
		
	}
	return self;
}

-(id) getDBPath:(id)dbFile {
	if (dbFile == NULL) {
		return NULL;
	}
	NSString *dbPath = [NSString stringWithFormat:@"%@/%@", appDocsPath, dbFile];
	return dbPath;
}

-(int)queryUserVersion: (sqlite3*) db {
	// get current database version of schema
	static sqlite3_stmt *stmt_version;
	int databaseVersion;
	
	if(sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt_version, NULL) == SQLITE_OK) {
		while(sqlite3_step(stmt_version) == SQLITE_ROW) {
			databaseVersion = sqlite3_column_int(stmt_version, 0);
			NSLog(@"%s: version %d", __FUNCTION__, databaseVersion);
		}
		NSLog(@"%s: the databaseVersion is: %d", __FUNCTION__, databaseVersion);
	} else {
		NSLog(@"%s: ERROR Preparing: , %s", __FUNCTION__, sqlite3_errmsg(db) );
	}
	sqlite3_finalize(stmt_version);
	
	return databaseVersion;
}

-(void) remove: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
	NSString *callback = [arguments objectAtIndex:0];	
	NSString *dbPath = [self getDBPath:[arguments objectAtIndex:1]];
	NSMutableDictionary *resultSet = [NSMutableDictionary dictionaryWithCapacity:0];
	
	BOOL success;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSError *error;
	success = [fileManager fileExistsAtPath:dbPath];
		
	if (!success){
		[resultSet setObject:@"Database path not found" forKey:@"message"];
		[resultSet setObject:@"2" forKey:@"status"];
    	CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
												messageAsDictionary:resultSet];
		[self writeJavascript: [result toErrorCallbackString:callback]];
		return;
	}
	
	if (dbPath == NULL) {
		[resultSet setObject:@"You must specify database path" forKey:@"message"];
		[resultSet setObject:@"2" forKey:@"status"];
    	CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
												messageAsDictionary:resultSet];
		[self writeJavascript: [result toErrorCallbackString:callback]];
		return;
	}
	
	success = [fileManager removeItemAtPath:dbPath error:&error];
    if (!success){
    	NSLog(@"Error: %@", [error localizedDescription]);
		[resultSet setObject:[error localizedDescription] forKey:@"message"];
		[resultSet setObject:@"2" forKey:@"status"];
    	CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
												messageAsDictionary:resultSet];
		[self writeJavascript: [result toErrorCallbackString:callback]];
    }
	else {
		[resultSet setObject:@"Db was removed" forKey:@"message"];		
		CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
												messageAsDictionary:resultSet];
		[self writeJavascript: [result toSuccessCallbackString:callback]];
    }
}

-(void) open: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
	NSString *callback = [arguments objectAtIndex:0];	
	NSString *dbPath = [self getDBPath:[arguments objectAtIndex:1]];
	NSMutableDictionary *resultSet = [NSMutableDictionary dictionaryWithCapacity:0];
		
	BOOL success;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSError *error;
	success = [fileManager fileExistsAtPath:dbPath];
	int status = 0;
	int version = 0;
	NSObject *_version;
	NSObject *_status;
	
	if (!success){
		status = 1;
		NSString* fullFileName = [arguments objectAtIndex:1];
		NSString* fileName = [[fullFileName lastPathComponent] stringByDeletingPathExtension];
		NSString* extension = [fullFileName pathExtension];
		NSString *dbPath2 = [[NSBundle mainBundle] pathForResource:fileName ofType:extension];
        NSLog(@"%s: path is: %@", __FUNCTION__, dbPath2);
		if (dbPath2 != NULL){
			success = [fileManager copyItemAtPath:dbPath2 toPath:dbPath error:&error];
			if (success){
				status = 2;
			}
		}
	}
	
	
	if (dbPath == NULL) {
		[resultSet setObject:@"You must specify database path" forKey:@"message"];		
		CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
												messageAsDictionary:resultSet];		
		[self writeJavascript: [result toErrorCallbackString:callback]];
		return;
	}
	
	sqlite3 *db;
	const char *path = [dbPath UTF8String];
	
	if (sqlite3_open(path, &db) != SQLITE_OK) {	
		        NSLog(@"%s: path is: %s", __FUNCTION__, sqlite3_errmsg(db));
		
		[resultSet setObject:@"Unable to open DB" forKey:@"message"];		
		CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
												messageAsDictionary:resultSet];		
		[self writeJavascript: [result toErrorCallbackString:callback]];
		return;
	}
	
	version = [self queryUserVersion:db];
	_version = [NSNumber numberWithInt:version];
	[resultSet setObject:_version forKey:@"version"];
	
	_status = [NSNumber numberWithInt:status];
	[resultSet setObject:_status forKey:@"status"];
	[resultSet setObject:dbPath forKey:@"systemPath"];
    
    NSLog(@"%s: sqlite3_get_autocommit::open , %d, %@", __FUNCTION__,  sqlite3_get_autocommit(db) , dbPath );
	
	NSValue *dbPointer = [NSValue valueWithPointer:db];
	[openDBs setObject:dbPointer forKey: dbPath];
		
	CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
											messageAsDictionary:resultSet];
	[self writeJavascript: [result toSuccessCallbackString:callback]];
}

-(void) backgroundExecuteSqlBatch: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{	
	[self performSelector:@selector(_executeSqlBatch:) withObject:arguments afterDelay:0.001];
}

-(void) backgroundExecuteSql: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
	[self performSelector:@selector(_executeSql:) withObject:arguments afterDelay:0.001];
}

-(void) _executeSqlBatch:(NSMutableArray*)arguments
{
	[self executeSqlBatch:arguments withDict:NULL];
}

-(void) _executeSql:(NSMutableArray*)arguments
{
	NSMutableArray *dict = [arguments objectAtIndex:2];	
	NSMutableDictionary *query = [NSMutableDictionary dictionaryWithCapacity:0];
	[query setObject:dict forKey:@"query"];
	[self executeSql:arguments withDict:query];
}

-(void) executeSqlBatch: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
	NSString *callback = [arguments objectAtIndex:0];	
	NSString *dbPath = [self getDBPath:[arguments objectAtIndex:1]];
	
    if (dbPath == NULL) {
    	CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
												messageAsString:@"You must specify database path"];
		[self writeJavascript: [result toErrorCallbackString:callback]];		
		return;
	}
    
    NSValue *dbPointer = [openDBs objectForKey:dbPath];
	if (dbPointer == NULL) {
		CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
													messageAsString:@"No such database, you must open it first"];
		[self writeJavascript: [result toErrorCallbackString:callback]];
		return;
	}
    
	sqlite3 *db = [dbPointer pointerValue];
	
    NSMutableArray *executes = [arguments objectAtIndex:2];
	for (NSMutableArray *dict in executes) {
		
		NSMutableDictionary *query = [NSMutableDictionary dictionaryWithCapacity:0];
		[query setObject:@"true" forKey:@"batch"];
		[query setObject:dict forKey:@"query"];
		
		BOOL ret = [self executeSql:arguments withDict:query];
        if (!ret){
            if ( sqlite3_get_autocommit(db) == 0){
                sqlite3_exec(db, "ROLLBACK", NULL, NULL, NULL);
            }
			CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
														messageAsString:[NSString stringWithFormat: @"%s", sqlite3_errmsg(db)]];
			[self writeJavascript: [result toErrorCallbackString:callback]];
            return;
        }
	}
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
											messageAsString:@"Success transaction"];
	[self writeJavascript: [result toSuccessCallbackString:callback]];
}

-(BOOL) executeSql: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
	NSString *callback = [arguments objectAtIndex:0];	
	NSString *dbPath = [self getDBPath:[arguments objectAtIndex:1]];	
	NSString *batch = [options objectForKey:@"batch"];
	NSMutableArray *query_parts = [options objectForKey:@"query"];
	NSString *query = [query_parts objectAtIndex:0];
	
	if (dbPath == NULL) {
		CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
													messageAsString:@"You must specify database path"];
		[self writeJavascript: [result toErrorCallbackString:callback]];		
		return false;
	}
	if (query == NULL) {
		CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
													messageAsString:@"You must specify a query to execute"];
		[self writeJavascript: [result toErrorCallbackString:callback]];		
		return false;
	}
	
	NSValue *dbPointer = [openDBs objectForKey:dbPath];
	if (dbPointer == NULL) {
		CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
													messageAsString:@"No such database, you must open it first"];
		[self writeJavascript: [result toErrorCallbackString:callback]];
		return false;
	}
	sqlite3 *db = [dbPointer pointerValue];
	
	const char *sql_stmt = [query UTF8String];
    
	char *errMsg = NULL;
	sqlite3_stmt *statement;
	int result, i, column_type, count;
	int previousRowsAffected, nowRowsAffected, diffRowsAffected;
	long long previousInsertId, nowInsertId;
	BOOL keepGoing = YES;
	BOOL hasInsertId;
	NSMutableDictionary *resultSet = [NSMutableDictionary dictionaryWithCapacity:0];
	NSMutableArray *resultRows = [NSMutableArray arrayWithCapacity:0];
	NSMutableDictionary *entry;
	NSObject *columnValue;
	NSString *columnName;
	NSString *bindval;
	NSObject *insertId;
	NSObject *rowsAffected;
	
	hasInsertId = NO;
	previousRowsAffected = sqlite3_total_changes(db);
	previousInsertId = sqlite3_last_insert_rowid(db);
    
    //NSLog(@"%s: sqlite3_get_autocommit: , %d", __FUNCTION__,  sqlite3_get_autocommit(db)  );
    
	
	if (sqlite3_prepare_v2(db, sql_stmt, -1, &statement, NULL) != SQLITE_OK) {
		errMsg = (char *) sqlite3_errmsg (db);
		keepGoing = NO;
        
	} else {
		for (int b = 1; b < query_parts.count; b++) {
			bindval = [NSString stringWithFormat:@"%@", [query_parts objectAtIndex:b]];
			sqlite3_bind_text(statement, b, [bindval UTF8String], -1, SQLITE_TRANSIENT);
		}
	}
	
	while (keepGoing) {
		result = sqlite3_step (statement);
		switch (result) {
				
			case SQLITE_ROW:
				i = 0;
				entry = [NSMutableDictionary dictionaryWithCapacity:0];
				count = sqlite3_column_count(statement);
				
				while (i < count) {
					column_type = sqlite3_column_type(statement, i);
					switch (column_type) {
						case SQLITE_INTEGER:
							columnValue = [NSNumber numberWithDouble: sqlite3_column_double(statement, i)];
							columnName = [NSString stringWithFormat:@"%s", sqlite3_column_name(statement, i)];
							[entry setObject:columnValue forKey:columnName];
							break;
						case SQLITE_TEXT:
							columnValue = [NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, i)];
							columnName = [NSString stringWithFormat:@"%s", sqlite3_column_name(statement, i)];
							[entry setObject:columnValue forKey:columnName];
							break;
						case SQLITE_BLOB:
							
							break;
						case SQLITE_FLOAT:
							columnValue = [NSNumber numberWithFloat: sqlite3_column_double(statement, i)];
							columnName = [NSString stringWithFormat:@"%s", sqlite3_column_name(statement, i)];
							[entry setObject:columnValue forKey:columnName];
							break;
						case SQLITE_NULL:
							break;
					}
					i++;
					
				}
				[resultRows addObject:entry];
				break;
				
			case SQLITE_DONE:
				nowRowsAffected = sqlite3_total_changes(db);
				diffRowsAffected = nowRowsAffected - previousRowsAffected;
				rowsAffected = [NSNumber numberWithInt:diffRowsAffected];
				nowInsertId = sqlite3_last_insert_rowid(db);
				if (previousInsertId != nowInsertId) {
					hasInsertId = YES;
					insertId = [NSNumber numberWithLongLong:sqlite3_last_insert_rowid(db)];
				}
				keepGoing = NO;
				break;
				
			default:
				errMsg = "SQL statement error";
				keepGoing = NO;
		}
	}
	
	sqlite3_finalize (statement);
	
	if (errMsg != NULL) {
		if (batch != nil){
			CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
													messageAsString:[NSString stringWithFormat: @"SQL statement error :%s", errMsg]];
			[self writeJavascript: [result toErrorCallbackString:callback]];
		}		
        return false;
	} else {
		[resultSet setObject:resultRows forKey:@"rows"];
		[resultSet setObject:rowsAffected forKey:@"rowsAffected"];
		if (hasInsertId) {
			[resultSet setObject:insertId forKey:@"insertId"];
		}
		if (batch == NULL){
			CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
												messageAsDictionary:resultSet];
			[self writeJavascript: [result toSuccessCallbackString:callback]];
		}
        return true;
	}
}

-(void) close: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{	
	NSString *callback = [arguments objectAtIndex:0];	
	NSString *dbPath = [self getDBPath:[arguments objectAtIndex:1]];
	
	if (dbPath == NULL) {
		CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
													messageAsString:@"You must specify database path"];
		[self writeJavascript: [result toErrorCallbackString:callback]];
		return;
	}
	
	NSValue *val = [openDBs objectForKey:dbPath];
	sqlite3 *db = [val pointerValue];
	if (db == NULL) {
		CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
													messageAsString:@"Specified db was not open"];
		[self writeJavascript: [result toErrorCallbackString:callback]];
		return;
	}
	sqlite3_close (db);
	
	CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
											messageAsString:@"db closed"];
	[self writeJavascript: [result toSuccessCallbackString:callback]];
}

-(void)dealloc
{
	int i;
	NSArray *keys = [openDBs allKeys];
	NSValue *pointer;
	NSString *key;
	sqlite3 *db;
	
	/* close db the user forgot */
	for (i=0; i<[keys count]; i++) {
		key = [keys objectAtIndex:i];
		pointer = [openDBs objectForKey:key];
		db = [pointer pointerValue];
		sqlite3_close (db);
	}
	
	[openDBs release];
	[appDocsPath release];
	[super dealloc];
}

@end