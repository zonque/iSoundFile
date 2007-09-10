//
//  ChannelTableSource.h
//  iSoundFile
//
//  Created by d on 9/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ChannelTableSource : NSObject {
    int numChannels;
    bool state[0x100];
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

@end
