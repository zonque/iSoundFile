//
//  AudioRenderer.h
//  iSoundFile
//
//  Created by d on 9/9/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define FILE_BUFFER_SIZE (1024*512)

@interface AudioRenderer : NSObject {
    SNDFILE *sndfile;
    SF_INFO sfinfo;
    AudioUnit au_unit;
    int current_buffer_pos;
    float file_buffer[FILE_BUFFER_SIZE];
    int current_buffer_start;
    sf_count_t buffer_vpos;
    int leftMapping, rightMapping;
}

- (void) set_sndfile: (SNDFILE *) sndfile : (SF_INFO *) info;
- (void) play;
- (void) pause;
- (void) update_buffer;
- (void) seek: (sf_count_t) pos;
- (void) setLeftOutputMapping: (int) channel;
- (void) setRightOutputMapping: (int) channel;
- (sf_count_t) currentPosition;

@end
