

#import "RadeonBiosConnector.h"

@implementation RadeonBiosConnector
- (BOOL)isDigital
{
    return _transmitter != nil;
}

-(id) copyWithZone: (NSZone *) zone
{
    /*YourObject *copy = [[YourObject allocWithZone: zone] init];
    
    [copy setNombre: self.nombre];
    [copy setLinea: self.linea];
    [copy setTags: self.tags];
    [copy setHtmlSource: self.htmlSource];
    
    return copy;*/
    
    RadeonBiosConnector* copy = [[RadeonBiosConnector allocWithZone:zone] init];
    
    copy.index = self.index;
    copy.type = self.type;
    copy.encoder = self.encoder;
    copy.transmitter = self.transmitter;
    copy.i2cid = self.i2cid;
    copy.osxSenseId = self.osxSenseId;
    copy.objectId = self.objectId;
    
    return copy;
}
@end
