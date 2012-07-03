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

-(void) respond: (id)cb withString:(NSString *)str withType:(NSString *)type {
	if (cb != NULL) {
		NSString* jsString = [NSString stringWithFormat:@"PGSQLitePlugin.handleCallback('%@', '%@', %@);", cb, type, str ];
		[self writeJavascript:jsString];
	}
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
	NSString *callback = [options objectForKey:@"callback"];
	NSString *dbPath = [self getDBPath:[options objectForKey:@"path"]];
	
	BOOL success;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSError *error;
	success = [fileManager fileExistsAtPath:dbPath];
	
	
	if (!success){
		[self respond:callback withString:@"{ message: 'Database path not found', status : 0 }" withType:@"error"];
		return;
	}
	
	if (dbPath == NULL) {
		[self respond:callback withString:@"{ message: 'You must specify database path', status : 1 }" withType:@"error"];
		return;
	}
	
	success = [fileManager removeItemAtPath:dbPath error:&error];
    if (!success){
    	NSLog(@"Error: %@", [error localizedDescription]);
    	[self respond:callback withString:@"{ message: 'Can't remove db', status : 2 }" withType:@"error"];
    }
	else {
		NSLog(@"database %@ was removed", dbPath);
		[self respond:callback withString:@"{ message: 'Db was removed' }" withType:@"success"];
    }
}

-(void) open: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
	NSString *callback = [options objectForKey:@"callback"];
	NSString *dbPath = [self getDBPath:[options objectForKey:@"path"]];
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
		NSString* fullFileName = [options objectForKey:@"path"];
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
		[self respond:callback withString:@"{ message: 'You must specify database path' }" withType:@"error"];
		return;
	}
	
	sqlite3 *db;
	const char *path = [dbPath UTF8String];
	
	if (sqlite3_open(path, &db) != SQLITE_OK) {
		[self respond:callback withString:@"{ message: 'Unable to open DB' }" withType:@"error"];
		return;
	}
	
	version = [self queryUserVersion:db];
	_version = [NSNumber numberWithInt:version];
	[resultSet setObject:_version forKey:@"version"];
	
	_status = [NSNumber numberWithInt:status];
	[resultSet setObject:_status forKey:@"status"];
	[resultSet setObject:dbPath forKey:@"systemPath"];
    
    NSLog(@"%s: sqlite3_get_autocommit::open , %d", __FUNCTION__,  sqlite3_get_autocommit(db)  );
	
	NSValue *dbPointer = [NSValue valueWithPointer:db];
	[openDBs setObject:dbPointer forKey: dbPath];
	[self respond:callback withString:[resultSet JSONString] withType:@"success"];
}

-(void) backgroundExecuteSqlBatch: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
	[self performSelector:@selector(_executeSqlBatch:) withObject:options afterDelay:0.001];
}

-(void) backgroundExecuteSql: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
	[self performSelector:@selector(_executeSql:) withObject:options afterDelay:0.001];
}

-(void) _executeSqlBatch:(NSMutableDictionary*)options
{
	[self executeSqlBatch:NULL withDict:options];
}

-(void) _executeSql:(NSMutableDictionary*)options
{
	[self executeSql:NULL withDict:options];
}

-(void) executeSqlBatch: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
    NSString *callback = [options objectForKey:@"callback"];
    NSString *dbPath = [self getDBPath:[options objectForKey:@"path"]];
    if (dbPath == NULL) {
		[self respond:callback withString:@"{ message: 'You must specify database path' }" withType:@"error"];
		return;
	}
    
    NSValue *dbPointer = [openDBs objectForKey:dbPath];
	if (dbPointer == NULL) {
		[self respond:callback withString:@"{ message: 'No such database, you must open it first' }" withType:@"error"];
		return;
	}
    
	sqlite3 *db = [dbPointer pointerValue];
	
    NSMutableArray *executes = [options objectForKey:@"executes"];
	for (NSMutableDictionary *dict in executes) {
		BOOL ret = [self executeSql:NULL withDict:dict];
        if (!ret){
            if ( sqlite3_get_autocommit(db) == 0){
                sqlite3_exec(db, "ROLLBACK", NULL, NULL, NULL);
            }
            [self respond:callback withString:[NSString stringWithFormat:@"{ message: 'SQL statement error : %s' }", sqlite3_errmsg(db)] withType:@"error"];
            return;
        }
	}
    [self respond:callback withString:@"{ message: 'Success transaction' }" withType:@"success"];
}

-(BOOL) executeSql: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
	NSString *callback = [options objectForKey:@"callback"];
	NSString *dbPath = [self getDBPath:[options objectForKey:@"path"]];
	NSMutableArray *query_parts = [options objectForKey:@"query"];
	NSString *query = [query_parts objectAtIndex:0];
	
	if (dbPath == NULL) {
		[self respond:callback withString:@"{ message: 'You must specify database path' }" withType:@"error"];
		return false;
	}
	if (query == NULL) {
		[self respond:callback withString:@"{ message: 'You must specify a query to execute' }" withType:@"error"];
		return false;
	}
	
	NSValue *dbPointer = [openDBs objectForKey:dbPath];
	if (dbPointer == NULL) {
		[self respond:callback withString:@"{ message: 'No such database, you must open it first' }" withType:@"error"];
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
		[self respond:callback withString:[NSString stringWithFormat:@"{ message: 'SQL statement error : %s' }", errMsg] withType:@"error"];
        return false;
	} else {
		[resultSet setObject:resultRows forKey:@"rows"];
		[resultSet setObject:rowsAffected forKey:@"rowsAffected"];
		if (hasInsertId) {
			[resultSet setObject:insertId forKey:@"insertId"];
		}
		[self respond:callback withString:[resultSet JSONString] withType:@"success"];
        return true;
	}
}

-(void) close: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
	NSString *callback = [options objectForKey:@"callback"];
	NSString *dbPath = [self getDBPath:[options objectForKey:@"path"]];
	if (dbPath == NULL) {
		[self respond:callback withString:@"{ message: 'You must specify database path' }" withType:@"error"];
		return;
	}
	
	NSValue *val = [openDBs objectForKey:dbPath];
	sqlite3 *db = [val pointerValue];
	if (db == NULL) {
		[self respond:callback withString: @"{ message: 'Specified db was not open' }" withType:@"error"];
	}
	sqlite3_close (db);
	[self respond:callback withString: @"{ message: 'db closed' }" withType:@"success"];
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