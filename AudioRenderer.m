//
//  AudioRenderer.m
//  iSoundFile
//
//  Created by d on 9/9/07.
//  Copyright 2007 caiaq. All rights reserved.
//

#import <CoreAudio/CoreAudio.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <AudioUnit/AUComponent.h>
#import <AudioUnit/AudioOutputUnit.h>
#import <AudioUnit/AudioUnitProperties.h>
#import <AudioUnit/AudioUnitParameters.h>
#import <sndfile.h>
#import "AudioRenderer.h"

@implementation AudioRenderer

- (int) read_buffered: (float **) buf : (int) num
{
    if (current_buffer_start >= FILE_BUFFER_SIZE) {
        bzero(file_buffer, num * sizeof(float));
        *buf = file_buffer;
        return num;
    }
        
    *buf = file_buffer + current_buffer_start;
  
    if (buffer_vpos + (num * sfinfo.channels) > sfinfo.frames)
        num -= (buffer_vpos + (num * sfinfo.channels)) - sfinfo.frames;
    
    current_buffer_start += num;
    buffer_vpos += num;
    return num;
}

- (void) update_buffer
{
    if (current_buffer_start > FILE_BUFFER_SIZE/2) {
        printf("rebuffering.\n");
        int rest = FILE_BUFFER_SIZE - current_buffer_start;
        memmove(file_buffer, file_buffer + current_buffer_start, rest * sizeof(float));
        current_buffer_start = 0;
        sf_read_float(sndfile, file_buffer + rest, FILE_BUFFER_SIZE - rest);
    }
}

static OSStatus sf_coreaudio_render_proc (void *this,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp *inTimeStamp,
                                          unsigned int inBusNumber,
                                          unsigned int inNumberFrames,
                                          AudioBufferList * ioData)
{
    AudioRenderer *ar = (AudioRenderer *) this;
    int to_read = (inNumberFrames / 2) * ar->sfinfo.channels;
    float *destbuf = ioData->mBuffers[0].mData;
    int frames_read = 0;

    while (frames_read < inNumberFrames) {
        float *buf;
        int r = [ar read_buffered: &buf : to_read];
        frames_read += r / ar->sfinfo.channels;
        float *p = buf;

//        
        [[NSNotificationCenter defaultCenter]
                postNotificationName:@"filePositionChanged" object:ar];

        if (r < to_read) {
            [[NSNotificationCenter defaultCenter]
                    postNotificationName:@"EOF" object:ar];
            return noErr;
        }
        
        while (r > 0) {
            destbuf[0] = p[ar->leftMapping];
            destbuf[1] = p[ar->rightMapping];
            destbuf += 2;
            p += ar->sfinfo.channels;
            r -= ar->sfinfo.channels;
        }
    }

    return noErr;
}

- (void) set_sndfile : (SNDFILE *) s : (SF_INFO *) info
{
        OSStatus err;
        AURenderCallbackStruct input;
        ComponentDescription desc;
        Component au_component, converter_component;
        AudioStreamBasicDescription format;
        AudioUnitConnection connection;
        AudioUnit converter_unit;

        sndfile = s;
        memcpy(&sfinfo, info, sizeof(*info));
        
        /* find an audio output unit */
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_DefaultOutput;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;    
        au_component = FindNextComponent (NULL, &desc);

        if (au_component == NULL) {
            printf("Unable to find a usable audio output unit component\n");
            return;
        }
    
        OpenAComponent (au_component, &au_unit);

        /* find a converter unit */
        desc.componentType = kAudioUnitType_FormatConverter;
        desc.componentSubType = kAudioUnitSubType_AUConverter;    
        converter_component = FindNextComponent(NULL, &desc);

        if (converter_component == NULL) {
            printf("Unable to find a usable audio converter unit component\n");
            return;
        }
        
        OpenAComponent(converter_component, &converter_unit);


      /* set up the render procedure */
      input.inputProc = (AURenderCallback) sf_coreaudio_render_proc;
      input.inputProcRefCon = self;

      AudioUnitSetProperty (converter_unit,
                            kAudioUnitProperty_SetRenderCallback,
                            kAudioUnitScope_Input,
                            0, &input, sizeof(input));

      /* connect the converter unit to the audio output unit */
      connection.sourceAudioUnit = converter_unit;
      connection.sourceOutputNumber = 0;
      connection.destInputNumber = 0;
      AudioUnitSetProperty (au_unit,
                            kAudioUnitProperty_MakeConnection,
                            kAudioUnitScope_Input, 0, 
                            &connection, sizeof(connection));

      /* set up the audio format we want to use */
      format.mSampleRate   = sfinfo.samplerate;
      format.mFormatID     = kAudioFormatLinearPCM;
      format.mFormatFlags = kAudioFormatFlagsNativeFloatPacked;
        
      format.mBitsPerChannel   = 32;
      format.mChannelsPerFrame = 2;
      format.mBytesPerFrame    = 2 * (32 / 8);
      format.mFramesPerPacket  = 1;
      format.mBytesPerPacket   = format.mBytesPerFrame;
     
      AudioUnitSetProperty (converter_unit,
                            kAudioUnitProperty_StreamFormat,
                            kAudioUnitScope_Input,
                            0, &format, sizeof (format));

      /* boarding completed, now initialize and start the units... */
      err = AudioUnitInitialize (converter_unit);
      if (err) {
          printf("failed to AudioUnitInitialize(converter_unit)\n");
          return;
      }

      err = AudioUnitInitialize (au_unit);
      if (err) {
          printf("failed to AudioUnitInitialize(au_unit)\n");
          return;
      }

    current_buffer_start = 0;
    sf_read_float(sndfile, file_buffer, FILE_BUFFER_SIZE);
}


- (void) play
{
    int err = AudioOutputUnitStart(au_unit);
    if (err)
        printf("AudioOutputUnitStart returned %d\n", err);
}

- (void) pause
{
    int err = AudioOutputUnitStop(au_unit);
    if (err)
        printf("AudioOutputUnitStop returned %d\n", err);
}

- (void) seek: (sf_count_t) pos
{
    buffer_vpos = pos;
    sf_seek(sndfile, buffer_vpos, SEEK_SET);
    current_buffer_start = 0;
    sf_read_float(sndfile, file_buffer, FILE_BUFFER_SIZE);
}

- (void) setLeftOutputMapping: (int) channel
{
    leftMapping = channel;
}

- (void) setRightOutputMapping: (int) channel
{
    rightMapping = channel;
    printf("left: %d right: %d\n", leftMapping, rightMapping);
}

- (void) dealloc
{
    AudioOutputUnitStop(au_unit);
    [super dealloc];
}

- (sf_count_t) currentPosition
{
    return buffer_vpos;
}

@end
