//
//  metajobs.m
//  gstuffer
//
//  Created by Charles Parnot on 7/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "GSMetajobs.h"
#import "GSLog.h"
#import "GSMain.h"
#import "XGSInputInterface.h"
#import "XGSTaskSource.h"
#import "XGSValidator.h"
#import "XGSParser.h"
#import "GSUserDefaults.h"

// 10 seconds is a minimum hard limit for disk polling
#define MINIMUM_POLLING_INTERVAL 10

// constant strings
NSString *pendingMetajobsSubdirectory = @"pending";
NSString *runningMetajobsSubdirectory = @"running";
NSString *doneMetajobsSubdirectory = @"done";
NSString *testsMetajobsSubdirectory = @"tests";

NSString *metajobCommandsFile = @"commands.txt";
NSString *metajobParametersFile = @"parameters.plist";
NSString *metajobResultsDirectory = @"results";

@interface GSMetajobs (GSMetajobsPrivate)
- (void)fetchMetajobs;
- (void)initializeMetajobDirectory;
- (void)inspectMetajobDirectory:(NSTimer *)timer;
- (BOOL)isValidMetajobDirectory:(NSString *)path;
- (GEZMetaJob *)newMetaJobWithPath:(NSString *)metajobDirectoryPath;
- (GEZMetaJob *)existingMetaJobWithPath:(NSString *)metajobDirectoryPath;
- (BOOL)checkMetaJobDone:(GEZMetaJob *)metaJob;
- (NSArray *)allowedParameterKeys;
@end

@implementation GSMetajobs


//@synthesize pollingInterval;
//@synthesize metajobsDirectory;
@synthesize running;



- (id)init
{
	self = [super init];
	if ( self != nil ) {
		metajobs = [[NSMutableSet alloc] init];
		//pollingInterval = [[GSUserDefaults gstufferUserDefaults] doubleForKey:@"MetajobsPollingTimeInterval"];
		//metajobsDirectory = [[[GSUserDefaults gstufferUserDefaults] objectForKey:@"MetajobsDirectory"] retain];
		running = NO;
	}
	return self;
}

- (void)dealloc
{
	[self stop];
	for ( GEZMetaJob *metajob in metajobs )
		[[metajob dataSource] release];
	[metajobs release];
	//[metajobsDirectory release];
	[super dealloc];
}

- (void)start
{
	self.running = YES;

	[self initializeMetajobDirectory];
	[self fetchMetajobs];
	[self inspectMetajobDirectory:nil];

}

- (void)stop
{
	self.running = NO;
}

- (NSString *)metajobsDirectory
{
	return [[GSUserDefaults gstufferUserDefaults] objectForKey:@"MetajobsDirectory"];
}

@end

@implementation GSMetajobs (GSMetajobsPrivate)

- (void)fetchMetajobs
{
	//to retrieve ALL records for a given entity, one can use a fetch request with no predicate
	NSManagedObjectContext *context = [GEZManager managedObjectContext];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[NSEntityDescription entityForName:GEZMetaJobEntityName inManagedObjectContext:context]];
	NSError *error = nil;
	NSArray *results = [context executeFetchRequest:request error:&error];
	if ( error != nil || results == nil ) {
		GSLog(@"error with fetch request for all GEZMetaJob:\n%@", error);
		return;
	}
	[metajobs addObjectsFromArray:results];
	for ( GEZMetaJob *job in metajobs ) {
		[job setDelegate:self];
		[job start];
	}
	NSArray *tempMetajobs = [[metajobs copy] autorelease];
	for ( GEZMetaJob *job in tempMetajobs )
		[self checkMetaJobDone:job];
}


// the 'metajobs' directory contains 4 subdirs:
// metajobs/pending
// metajobs/running
// metajobs/done
// metajobs/tests
- (void)initializeMetajobDirectory
{
	GSLog(@"%s", _cmd );
	NSError *error = nil;
	NSString *metajobsDirectory = [self metajobsDirectory];

	// create the subdirs
	NSArray *subdirs = [NSArray arrayWithObjects:metajobsDirectory, [metajobsDirectory stringByAppendingPathComponent:pendingMetajobsSubdirectory], [metajobsDirectory stringByAppendingPathComponent:runningMetajobsSubdirectory], [metajobsDirectory stringByAppendingPathComponent:doneMetajobsSubdirectory], [metajobsDirectory stringByAppendingPathComponent:testsMetajobsSubdirectory], nil];
	for ( NSString *subdir in subdirs ) {
		BOOL isDir = YES;
		if (  [[NSFileManager defaultManager] fileExistsAtPath:subdir isDirectory:&isDir] == NO ) {
			error = nil;
			GSLog(@"Creating subdir %@", subdir);
			if ( [[NSFileManager defaultManager] createDirectoryAtPath:subdir withIntermediateDirectories:YES attributes:nil error:&error] == NO )
				GSLog(@"Could not create subdir %@ due to error:\n%@", subdir, error);
		} else if ( isDir == NO ) {
			GSLog(@"Could not create subdir %@ because path already exists and it is a file, not a directory", subdir);
		}		
	}
	
	// the 'tests' subdir is populated based on the tests directory in the application package
	NSString *originals = [[NSBundle mainBundle] pathForResource:@"tests" ofType:@""];
	NSString *copies = [metajobsDirectory stringByAppendingPathComponent:testsMetajobsSubdirectory];
	error = nil;
	NSArray *tests = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:originals error:&error];
	if ( error != nil ) {
		GSLog(@"Could not read contents of directory %@ due to error:\n%@", originals, error);
		return;
	}
	for ( NSString *subdir in tests ) {
		NSString *source = [originals stringByAppendingPathComponent:subdir];
		NSString *destination = [copies stringByAppendingPathComponent:subdir];
		if ( [[NSFileManager defaultManager] fileExistsAtPath:destination isDirectory:NULL] == NO ) {
			GSLog(@"Copying test subdir %@ to %@", source, destination);
			error = nil;
			if ( [[NSFileManager defaultManager] copyItemAtPath:source toPath:destination error:&error] == NO )
				GSLog(@"Could not copy contents of test subdir %@ due to error:\n%@", subdir, error);
		}
	}
}

- (void)inspectMetajobDirectory:(NSTimer *)timer
{
	NSError *error = nil;
	
	if ( self.running == NO )
		return;
	
	// to repeat later
	NSInteger pollingInterval = [[GSUserDefaults gstufferUserDefaults] integerForKey:@"MetajobsPollingTimeInterval"];
	if ( pollingInterval < MINIMUM_POLLING_INTERVAL )
		pollingInterval = MINIMUM_POLLING_INTERVAL;
	[NSTimer scheduledTimerWithTimeInterval:pollingInterval target:self selector:@selector(inspectMetajobDirectory:) userInfo:nil repeats:NO];
	
	// directory with the running metajobs
	GSLog(@"%s [ %@ ]", _cmd, [NSDate date] );
	NSString *metajobsDirectory = [self metajobsDirectory];
	NSString *runningMetajobsSubdir = [metajobsDirectory stringByAppendingPathComponent:runningMetajobsSubdirectory];
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:runningMetajobsSubdir error:&error];
	if ( error != nil ) {
		GSLog(@"Could not list files in directory %@ due to error:\n%@", runningMetajobsSubdir, error);
		return;
	}
	
	// for each running metajob, update the parameters
	for ( NSString *file in files ) {
		
		NSString *metajobDirectoryPath = [runningMetajobsSubdir stringByAppendingPathComponent:file];
		
		if ( [self isValidMetajobDirectory:metajobDirectoryPath] ) {
			
			// parameters gathered from the paramters.plist file, if one is present
			NSArray *allowedParameters = [self allowedParameterKeys];
			NSString *parameterFile = [metajobDirectoryPath stringByAppendingPathComponent:metajobParametersFile];
			BOOL isDir = NO;
			if ( [[NSFileManager defaultManager] fileExistsAtPath:parameterFile isDirectory:&isDir] == YES && isDir == NO ) {
				GEZMetaJob *metaJob = [self existingMetaJobWithPath:metajobDirectoryPath];
				NSDictionary *parameters = [NSDictionary dictionaryWithContentsOfFile:parameterFile];
				NSArray *keys = [parameters allKeys];
				for ( NSString *key in keys ) {
					if ( [allowedParameters indexOfObject:key] != NSNotFound ) {
						id value = [parameters objectForKey:key];
						[metaJob setValue:value forKeyPath:key];
					} else
						GSLog(@"could not set value for key %@ because the key does not correspond to a valid parameter", key);
					[metaJob start];
				}
			}
			
		}
	}
	
	// directory with pending metajobs
	GSLog(@"%s [ %@ ]", _cmd, [NSDate date] );
	NSString *pendingMetajobsSubdir = [metajobsDirectory stringByAppendingPathComponent:pendingMetajobsSubdirectory];
	files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pendingMetajobsSubdir error:&error];
	if ( error != nil ) {
		GSLog(@"Could not list files in directory %@ due to error:\n%@", pendingMetajobsSubdir, error);
		return;
	}
	
	// each path inside that directory could be a new metajob
	for ( NSString *file in files ) {
		
		NSString *path = [pendingMetajobsSubdir stringByAppendingPathComponent:file];
		if ( [self isValidMetajobDirectory:path] ) {

			// add a prefix to the name of the directory, with a time stamp that should make that name unique when moving the metajob directory into the 'running', and later 'done', directories
			NSString *suffix = [NSString stringWithFormat:@" - %@", [[NSCalendarDate date] descriptionWithCalendarFormat:@"%Y-%m-%d-%H-%M-%S-%F"]];
			NSString *newName = [[[[path lastPathComponent] stringByDeletingPathExtension] stringByAppendingString:suffix] stringByAppendingPathExtension:@"gsmetajob"];
			NSString *newPath = [[metajobsDirectory stringByAppendingPathComponent:runningMetajobsSubdirectory] stringByAppendingPathComponent:newName];

			// move directory from 'pending' to 'running'
			error = nil;
			if ( [[NSFileManager defaultManager] moveItemAtPath:path toPath:newPath error:&error] == NO ){
				GSLog(@"Could not move directory %@ to %@ to error:\n%@", path, newPath, error);
			} else {
				
				// create new metajob
				GEZMetaJob *newMetajob = [self newMetaJobWithPath:newPath];
				if ( newMetajob == nil ) {
					GSLog(@"Could not create new metajob with path %@", newPath);
					if ( [[NSFileManager defaultManager] moveItemAtPath:path toPath:newPath error:&error] == NO )
						GSLog(@"Could not move directory %@ back to %@ to error:\n%@", newPath, path, error);
				} else {
					[metajobs addObject:newMetajob];
					[[[newMetajob dataSource] inputInterface] loadFile];
					[newMetajob start];
				}

			}
		}
	}
	
	
}

- (BOOL)isValidMetajobDirectory:(NSString *)path
{
	BOOL isDir = NO;
	NSString *commandsPath = [path stringByAppendingPathComponent:metajobCommandsFile];
	NSString *resultsPath = [path stringByAppendingPathComponent:metajobResultsDirectory];
	if ( [[path pathExtension] isEqualToString:@"gsmetajob"] == NO || [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] == NO || isDir == NO ) {
		GSLog(@"path %@ is not a valid metajob directory", path);
		return NO;
	}
	if ( [[NSFileManager defaultManager] fileExistsAtPath:commandsPath] == NO ) {
		GSLog(@"no file %@ in metajob directory %@", metajobCommandsFile, path);
		return NO;
	}
	if ( [[NSFileManager defaultManager] fileExistsAtPath:resultsPath isDirectory:&isDir] == NO ) {
		GSLog(@"creating subdirectory %@ in metajob directory %@", metajobResultsDirectory, path);
		NSError *error;
		if ( [[NSFileManager defaultManager] createDirectoryAtPath:resultsPath withIntermediateDirectories:NO attributes:nil error:&error] == NO ) {
			GSLog(@"could not create subdirectory %@ should in metajob directory %@, due to error:\n%@", metajobResultsDirectory, path, error);
			return NO;
		}
	} else if ( isDir == NO ) {
		GSLog(@"file %@ should be a directory in metajob directory %@", metajobResultsDirectory, path);
		return NO;
	}
	return YES;
}

- (GEZMetaJob *)newMetaJobWithPath:(NSString *)metajobDirectoryPath
{
	GSLog(@"%s [ %@ ]", _cmd, [NSDate date] );

	if ( [self isValidMetajobDirectory:metajobDirectoryPath] == NO )
		return nil;
	GSLog(@"creating new metajob for directory %@", metajobDirectoryPath);
		
	//get the context
	NSManagedObjectContext *context = [[GSMain sharedMainController] managedObjectContext];
			 
	//set up the input and output interface first...
	XGSInputInterface *input = [NSEntityDescription insertNewObjectForEntityForName:@"InputInterface" inManagedObjectContext:context];
	XGSOutputInterface *output = [NSEntityDescription insertNewObjectForEntityForName:@"OutputInterface" inManagedObjectContext:context];
	[input setValue:[metajobDirectoryPath stringByAppendingPathComponent:metajobCommandsFile] forKey:@"filePath"];
	[output setValue:[metajobDirectoryPath stringByAppendingPathComponent:metajobResultsDirectory] forKey:@"folderPath"];
	
	//... then the task source ...
	XGSValidator *filter = [NSEntityDescription insertNewObjectForEntityForName:@"Validator" inManagedObjectContext:context];
	XGSTaskSource *taskSource = [NSEntityDescription insertNewObjectForEntityForName:@"DataSource" inManagedObjectContext:context];
	[taskSource setValue:input       forKey:@"inputInterface"];
	[taskSource setValue:output      forKey:@"outputInterface"];
	[taskSource setValue:filter      forKey:@"validator"];
	
	//...then the metaJob
	GEZMetaJob *metaJob = [GEZMetaJob metaJobWithName:[[metajobDirectoryPath lastPathComponent] stringByDeletingPathExtension]];
	[metaJob setDataSource:taskSource];
	
	// the data source has to be retained, as it is only weakly coupled to the metaJob
	// we still have a reference to it via the metajob, which we retain, so we can get back to this object to release it when we get rid of the metajob object itself
	[taskSource retain];
	
	// more parameters gathered from the paramters.plist file, if one is present
	NSArray *allowedParameters = [self allowedParameterKeys];
	NSString *parameterFile = [metajobDirectoryPath stringByAppendingPathComponent:metajobParametersFile];
	BOOL isDir = NO;
	if ( [[NSFileManager defaultManager] fileExistsAtPath:parameterFile isDirectory:&isDir] == YES && isDir == NO ) {
		GSLog(@"loading parameters from file %@", parameterFile);
		NSDictionary *parameters = [NSDictionary dictionaryWithContentsOfFile:parameterFile];
		NSArray *keys = [parameters allKeys];
		for ( NSString *key in keys ) {
			if ( [allowedParameters indexOfObject:key] != NSNotFound ) {
				id value = [parameters objectForKey:key];
				[metaJob setValue:value forKeyPath:key];
			} else
				GSLog(@"could not set value for key %@ because the key does not correspond to a valid parameter", key);
		}
	}
	
	[metaJob setDelegate:self];
	
	return metaJob;
	
}

- (GEZMetaJob *)existingMetaJobWithPath:(NSString *)metajobDirectoryPath
{
	if ( [self isValidMetajobDirectory:metajobDirectoryPath] == NO )
		return nil;
	
	// check in the NSSet metajobs for a metajob with a compatible output path
	NSString *metaJobOutputPath = [metajobDirectoryPath stringByAppendingPathComponent:metajobResultsDirectory];
	for ( GEZMetaJob *metaJob in metajobs ) {
		if ( [[[metaJob dataSource] valueForKeyPath:@"outputInterface.folderPath"] isEqualToString:metaJobOutputPath] )
			return metaJob;
	}
	return nil;
}


- (BOOL)checkMetaJobDone:(GEZMetaJob *)metaJob
{
	if ( [[metaJob countTotalTasks] isEqualToNumber:[metaJob countDoneTasks]] == NO )
		return NO;
	GSLog(@"MetaJob %@ done", [metaJob name]);
	[metaJob suspend];
	
	// move directory from 'running' to 'done'
	NSString *oldPath = [[[[metaJob dataSource] inputInterface] filePath] stringByDeletingLastPathComponent];
	NSString *newPath = [[[self metajobsDirectory] stringByAppendingPathComponent:doneMetajobsSubdirectory] stringByAppendingPathComponent:[oldPath lastPathComponent]];
	GSLog(@"Moving directory %@ to %@", oldPath, newPath);
	NSError *error = nil;
	if ( [[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error] == NO ) {
		GSLog(@"Could not move directory %@ to %@ to error:\n%@", oldPath, newPath, error);
		return NO;
	}
	GSLog(@"Deleting MetaJob %@ from database", [metaJob name]);
	[metaJob deleteFromStore];
	[metajobs removeObject:[[metaJob retain] autorelease]];
	
	return YES;
}

- (NSArray *)allowedParameterKeys
{
	return [NSArray arrayWithObjects:@"dataSource.maxTasksPerFolder",
			@"dataSource.validator.failureIfAllFilesEmpty",
			@"dataSource.validator.failureIfNoFile",
			@"dataSource.validator.failureIfNothing",
			@"dataSource.validator.failureIfOneFileEmpty",
			@"dataSource.validator.failureIfStderrEmpty",
			@"dataSource.validator.failureIfStderrNonEmpty",
			@"dataSource.validator.failureIfStdoutEmpty",
			@"dataSource.validator.failureIfStdoutNonEmpty",
			@"maxBytesPerJob",
			@"maxFailuresPerTask",
			@"maxPendingJobs",
			@"maxSubmissionsPerTask",
			@"maxSubmittedTasks",
			@"maxSubmittingJobs",
			@"minSuccessesPerTask",
			@"name",
			@"shouldDeleteJobsAutomatically",
			@"tasksPerJob",
			nil];
}
@end

@implementation GSMetajobs (GSMetajobDelegate)

#pragma mark GEZMetajob delegate

- (void)metaJobDidStart:(GEZMetaJob *)metaJob
{
	GSLog(@"MetaJob %@: %s", [metaJob name], _cmd);
}
- (void)metaJobDidSuspend:(GEZMetaJob *)metaJob
{
	GSLog(@"MetaJob %@: %s", [metaJob name], _cmd);
}
- (void)metaJob:(GEZMetaJob *)metaJob didSubmitTaskAtIndex:(int)index
{
	GSLog(@"MetaJob %@: %s %d", [metaJob name], _cmd, index);
}
- (void)metaJob:(GEZMetaJob *)metaJob didProcessTaskAtIndex:(int)index
{
	GSLog(@"MetaJob %@: %s %d", [metaJob name], _cmd, index);
	[self checkMetaJobDone:metaJob];
}

@end
