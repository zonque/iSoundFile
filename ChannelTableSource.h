//
//  ChannelTableSource.h
//  iSoundFile
//
//  Created by d on 9/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum type {
    CONVERT_TABLE,
    PEAK_TABLE
};

#define MAX_CHANNELS 0x100

@interface ChannelTableSource : NSObject {
    int numChannels;
    int type;
    bool state[MAX_CHANNELS];
    double peakValue[MAX_CHANNELS];
    SF_INFO *sfinfo;
}

- (void)tableView:(NSTableView *)aTableView
    setObjectValue:anObject
    forTableColumn:(NSTableColumn *)aTableColumn
    row:(int)rowIndex;

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
    row:(int)rowIndex;

- (int) numberOfRowsInTableView:(NSTableView *)aTableView;
- (void) setNumChannels: (int) n;
- (bool) channelIsSelected: (int) channel;
- (void) setPeakIfHigher: (double) val channel: (int) chn;
- (void) setType: (int) t;
- (void) setSFinfo: (SF_INFO *) info;

@end
