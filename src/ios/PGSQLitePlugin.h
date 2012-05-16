#import <Foundation/Foundation.h>
#import <sqlite3.h>

#ifdef CORDOVA_FRAMEWORK
#import <Cordova/CDVPlugin.h>
#import <CORDOVA/JSONKit.h>
#import <Cordova/CDVURLProtocol.h>
#else
#import "CDVPlugin.h"
#import "JSON.h"
#import "CDVURLProtocol.h"
#endif


@interface PGSQLitePlugin : CDVPlugin {
	NSMutableDictionary *openDBs;
}

@property (nonatomic, copy) NSMutableDictionary *openDBs;
@property (nonatomic, retain) NSString *appDocsPath;

-(int)queryUserVersion: (sqlite3*) db;
-(void) remove: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
-(void) open:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
-(void) backgroundExecuteSqlBatch:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
-(void) backgroundExecuteSql:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
-(void) executeSqlBatch:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
-(BOOL) executeSql:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
-(void) _executeSqlBatch:(NSMutableDictionary*)options;
-(void) _executeSql:(NSMutableDictionary*)options;
-(void) close: (NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
-(void) respond: (id)cb withString:(NSString *)str withType:(NSString *)type;
-(id) getDBPath:(id)dbFile;

@end