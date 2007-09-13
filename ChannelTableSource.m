//
//  ChannelTableSource.m
//  iSoundFile
//
//  Created by d on 9/10/07.
//  Copyright 2007 caiaq. All rights reserved.
//

#import <sndfile.h>

#import "ChannelTableSource.h"

#define ARRAY_SIZE(a) (sizeof(a)/sizeof(a[0]))

@implementation ChannelTableSource

- (double) calcDecibels: (double) max
{      
    double decibels;

    switch (sfinfo->format & SF_FORMAT_SUBMASK) {
        case SF_FORMAT_PCM_U8:
        case SF_FORMAT_PCM_S8:
            decibels = max / 0x80 ;
            break ;

        case SF_FORMAT_PCM_16:
            decibels = max / 0x8000 ;
            break ;

        case SF_FORMAT_PCM_24:
            decibels = max / 0x800000 ;
            break ;

        case SF_FORMAT_PCM_32:
            decibels = max / 0x80000000 ;
            break ;

        case SF_FORMAT_FLOAT:
        case SF_FORMAT_DOUBLE:
            decibels = max / 1.0 ;
            break ;

        default:
            decibels = max / 0x8000 ;
            break ;
    }

    return 20.0 * log10 (decibels) ;
}

- (void)tableView:(NSTableView *)aTableView
    setObjectValue:anObject
    forTableColumn:(NSTableColumn *)aTableColumn
    row:(int)rowIndex
{
    switch (type) {
        case CONVERT_TABLE:
            if (anObject && [anObject intValue])
                state[rowIndex] = 1;
            else
                state[rowIndex] = 0;
            break;
    }
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
    row:(int)rowIndex
{
    if ([[aTableColumn identifier] isEqualToString: @"name"])
        return [NSString stringWithFormat: @"Channel #%d", rowIndex];

    switch (type) {
        case CONVERT_TABLE:
            return state[rowIndex] ? @"1" : nil;
        case PEAK_TABLE:
            return [NSString stringWithFormat: @"%.2f dB", [self calcDecibels: peakValue[rowIndex]]];
    }
    
    return nil;
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return numChannels;
}

-(void) setNumChannels: (int) n
{
    int i;
    
    if (n > ARRAY_SIZE(state))
        n = ARRAY_SIZE(state);
        
    numChannels = n;
    memset(state, 1, sizeof(state));

    for(i=0; i < ARRAY_SIZE(state); i++)
        peakValue[i] = 0.0;
}

- (void)setType: (int) t
{
    type = t;
}

- (void) setSFinfo: (SF_INFO *) info
{
    sfinfo = info;
}

- (bool) channelIsSelected: (int) channel
{
    return state[channel];
}

- (void) setPeakIfHigher: (double) val channel: (int) chn
{
    if (peakValue[chn] < val)
        peakValue[chn] = val;
}


@end
