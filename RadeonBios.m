

#import "RadeonBios.h"
#import "RadeonBiosConnector.h"
#import "radeon_bios_decode.h"


@implementation RadeonBios
//- (id)init
//{
//    self = [super init];
//    
//    if(!self)
//        return self;
//    
//    [self add]
//    
//    return self;
//}

- (id)initWithBios:(NSString *)path error:(NSError *__autoreleasing *)error
{
    self = [super init];
    
    if(!self)
        return self;
        
    BOOL success = radeon_bios_decode_wrapper(self, path, error);
    
    if(!success)
        return nil;
    
    return self;
}

- initWithBios: (NSString*)path andRedsockBiosDecode: (NSString*)redsockBiosDecode error: (NSError**)error
{
    self = [self initWithBios:path error:error];
    
    if(!self)
        return self;

    NSArray* connectors = [self readConnectorsFromBios:path withRedsockBiosDecode:redsockBiosDecode];
    
    _connectors = [self combineConnectorsFrom:self.connectors and:connectors];

    return self;
}


/**
 connectorsB only contains txmit
 */
- (NSArray*)combineConnectorsFrom: (NSArray*)connectorsA and:(NSArray*)connectorsB
{
    NSMutableArray* array = [NSMutableArray array];
    
    if(connectorsA.count != connectorsB.count)
        return nil;
    
    for(int i = 0; i < connectorsA.count; i++) {
        RadeonBiosConnector* conA = [connectorsA objectAtIndex:i];
        RadeonBiosConnector* conB = [connectorsB objectAtIndex:i];
        
        if(![conA.objectId isEqualToNumber:conB.objectId])
            NSLog(@"objectIds dont match");
        
        RadeonBiosConnector* resultingConnector = [conA copy];
        [array addObject:resultingConnector];
        
        if([conB isDigital])
            resultingConnector.transmitter = conB.transmitter;
    }
    
    return array;
}

/**
 Returns own connectors
 */
- (NSArray*)readConnectorsFromBios: (NSString*)path withRedsockBiosDecode: (NSString*)redsockBiosDecode
{
    NSMutableArray* connectors = [[NSMutableArray alloc] init];
    
    /**
     Problem: Eine ObjectID kann öfters vorkommen, nachdem wir hier den Transmitter herausfinden wollen
     bräuchten wir nur digitale Ausgänge beachten. Allerdings müssen die auch richtig geparsed werden ....
     */
    NSString* output = [self redsockBiosDecodeOutput:redsockBiosDecode biosPath:path];
    NSArray* lines = [output componentsSeparatedByString:@"\n"];
    
    RadeonBiosConnector* currentConnector = nil;
    
    for(NSString* line in lines) {
        /**
         Problem: Using redsockBiosDecode, I'm able to fill the missing transmitter fields in connectors but redsockbiosdecode doesn't display senseIds, so it's not able to match the tools output to our Connectors
         Solved: I'm saving objectId to map those connectors
         */
        
        NSString* trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if([trimmedLine hasPrefix:@"Connector Object Id "]) {
            //Connector Object Id [5] which is [VGA]

            NSArray* parts = [trimmedLine componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"[]"]];
            NSNumber* currentObjectId = [NSNumber numberWithInteger:[[parts objectAtIndex:1] integerValue]];
            
            //create new connector
            currentConnector = [[RadeonBiosConnector alloc] init];
            [connectors addObject:currentConnector];
            
            currentConnector.objectId = currentObjectId;
            
            
        } else if(currentConnector != nil && [trimmedLine rangeOfString:@"encoder obj id "].location != NSNotFound && [trimmedLine rangeOfString:@"txmit"].location != NSNotFound) {
            /**
             We don't want to catch lines like:
             encoder obj id [0x16] which is [INTERNAL_KLDSCP_DAC2] linkb: false
             but those for digital outputs like:
             encoder obj id [0x20] which is [INTERNAL_UNIPHY1 (osx txmit 0x21 [duallink 0x1] enc 0x3)] linkb: true
             */
            
            NSRange txmitRange = [trimmedLine rangeOfString:@"txmit"];
            NSString* lineAfterTxmit = [trimmedLine substringFromIndex:txmitRange.location];
            NSArray* parts = [lineAfterTxmit componentsSeparatedByString:@" "];
            NSString* txmitHex = [parts objectAtIndex:1];
            
            NSScanner* hexScanner = [NSScanner scannerWithString:txmitHex];
            unsigned int txmit;
            
            [hexScanner scanHexInt:&txmit];
            
            //set txmit
            currentConnector.transmitter = [NSNumber numberWithInt:txmit];
        }
        
    }
    
    return connectors;
}

- (NSString*)redsockBiosDecodeOutput:(NSString*)redsockBiosDecode biosPath:(NSString*)path
{
    NSTask* task = [[NSTask alloc] init];
    
    [task setCurrentDirectoryPath:NSHomeDirectory()];
    [task setLaunchPath:redsockBiosDecode];
    
    NSPipe* outputPipe = [NSPipe pipe];
    NSFileHandle* inputFile = [NSFileHandle fileHandleForReadingAtPath:path];
    
    [task setStandardOutput:outputPipe];
    [task setStandardError:outputPipe];
    [task setStandardInput:inputFile];
    [task launch];
    
    NSFileHandle* outputHandle = [outputPipe fileHandleForReading];
    NSData* outputData = [outputHandle readDataToEndOfFile];
    NSString* output = [[NSString alloc] initWithData:outputData encoding:NSASCIIStringEncoding];
    
    return output;
    
#if 0
    NSTask * task = [[NSTask alloc] init];
	NSPipe * newPipe = [NSPipe pipe];
	NSFileHandle * readHandle = [newPipe fileHandleForReading];
	NSData * inData;
	NSString * outString;
    
	[task setCurrentDirectoryPath:NSHomeDirectory()];
	[task setLaunchPath:path];
	[task setArguments:arguments];
	[task setStandardOutput:newPipe];
	[task setStandardError:newPipe];
	[task launch];
	inData = [readHandle readDataToEndOfFile];
	outString = [[NSString alloc] initWithData:inData encoding:NSASCIIStringEncoding];
    
    return outString;
#endif
    
}

- (void)updateIoPciMatch
{
    int devId_int = [_deviceId intValue] & 0xFFFF;
    int venId_int = [_vendorId intValue] & 0xFFFF;
    
    int res = devId_int << 16;
    res += venId_int;
    
    _ioPciMatch = [NSNumber numberWithInt:res];
}

- (void)setDeviceId:(NSNumber *)deviceId
{
    _deviceId = deviceId;
    
    [self updateIoPciMatch];
}

- (void)setVendorId:(NSNumber *)vendorId
{
    _vendorId = vendorId;
    
    [self updateIoPciMatch];
}
@end
