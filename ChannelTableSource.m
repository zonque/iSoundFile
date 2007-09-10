//
//  ChannelTableSource.m
//  iSoundFile
//
//  Created by d on 9/10/07.
//  Copyright 2007 caiaq. All rights reserved.
//

#import "ChannelTableSource.h"


@implementation ChannelTableSource

- (void)tableView:(NSTableView *)aTableView
    setObjectValue:anObject
    forTableColumn:(NSTableColumn *)aTableColumn
    row:(int)rowIndex
{
    if (anObject && [anObject intValue])
        state[rowIndex] = 1;
    else
        state[rowIndex] = 0;
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
    row:(int)rowIndex
{
    if ([[aTableColumn identifier] isEqualToString: @"name"])
        return [NSString stringWithFormat: @"Channel #%d", rowIndex];

    return state[rowIndex] ? @"1" : nil;
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return numChannels;
}

-(void) setNumChannels: (int) n
{
    if (n > sizeof(state) / sizeof(state[0]))
        n = sizeof(state) / sizeof(state[0]);
        
    numChannels = n;
    memset(state, 1, sizeof(state));
}

- (bool) channelIsSelected: (int) channel
{
    return state[channel];
}

@end
