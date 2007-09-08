#include <unistd.h>

#import <CoreAudio/CoreAudio.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <AudioUnit/AUComponent.h>
#import <AudioUnit/AudioOutputUnit.h>
#import <AudioUnit/AudioUnitProperties.h>
#import <AudioUnit/AudioUnitParameters.h>

#import <sndfile.h>
#import "SoundFile.h"


@implementation SoundFile

- (int) read_buffered: (float **) buf : (int) num
{
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
    SoundFile *sf = (SoundFile *) this;
    int left_map =  [sf->left_channel  indexOfSelectedItem];
    int right_map = [sf->right_channel indexOfSelectedItem];
    int to_read = (inNumberFrames / 2) * sf->sfinfo.channels;
    float *destbuf = ioData->mBuffers[0].mData;
    int frames_read = 0;

    while (frames_read < inNumberFrames) {
        float *buf;
        int r = [sf read_buffered: &buf : to_read];
        frames_read += r / sf->sfinfo.channels;
        float *p = buf;

        if (r < to_read) {
            [sf play: nil];
            return noErr;
        }
        
        while (r > 0) {
            destbuf[0] = p[left_map];
            destbuf[1] = p[right_map];
            destbuf += 2;
            p += sf->sfinfo.channels;
            r -= sf->sfinfo.channels;
        }
    }

    [sf->play_slider setIntValue: [sf->play_slider intValue] + frames_read];
    //[sf updatePlayPos];
    return noErr;
}

- (void) initCoreAudio
{
    OSStatus err;
    AURenderCallbackStruct input;
    ComponentDescription desc;
    Component au_component, converter_component;
    AudioStreamBasicDescription format;
    AudioUnitConnection connection;
    AudioUnit converter_unit;
    
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
  format.mFormatFlags  = kAudioFormatFlagIsFloat | kAudioFormatFlagIsBigEndian;
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

}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"SoundFile";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    const char *tmp;
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.


    SF_FORMAT_INFO	format_info;
    format_info.format = sfinfo.format;
    sf_command (sndfile, SFC_GET_FORMAT_INFO, &format_info, sizeof (format_info)) ;

    if (format_info.name == NULL) {
        [self close];
        return;
    }

    [label_format setStringValue: [NSString stringWithCString: format_info.name]];
    [label_samplerate setIntValue: sfinfo.samplerate];
    [label_channels setIntValue: sfinfo.channels];
    [label_frames setIntValue: sfinfo.frames];
    [label_length setStringValue: [NSString stringWithFormat: @"%llu:%02llu:%02llu.%03llu",
                                    (sfinfo.frames / (sfinfo.samplerate * 60ULL * 60ULL)),
                                    (sfinfo.frames / (sfinfo.samplerate * 60ULL)) % 60ULL,
                                    (sfinfo.frames / sfinfo.samplerate) % 60ULL,
                                    ((sfinfo.frames % sfinfo.samplerate) * 1000ULL) / sfinfo.samplerate ]];

    if (read_only) {
        [string_title setEnabled: NO];
        [string_copyright setEnabled: NO];
        [string_software setEnabled: NO];
        [string_artist setEnabled: NO];
        [string_comment setEnabled: NO];
        [string_date setEnabled: NO];
    }

    tmp = sf_get_string(sndfile, SF_STR_TITLE);
    if (tmp)
        [string_title       setStringValue: [NSString stringWithCString: tmp]];

    tmp = sf_get_string(sndfile, SF_STR_COPYRIGHT);
    if (tmp)
        [string_copyright   setStringValue: [NSString stringWithCString: tmp]];

    tmp = sf_get_string(sndfile, SF_STR_SOFTWARE);
    if (tmp)
        [string_software    setStringValue: [NSString stringWithCString: tmp]];
    
    tmp = sf_get_string(sndfile, SF_STR_ARTIST);
    if (tmp)
        [string_artist      setStringValue: [NSString stringWithCString: tmp]];
    
    tmp = sf_get_string(sndfile, SF_STR_COMMENT);
    if (tmp)
        [string_comment     setStringValue: [NSString stringWithCString: tmp]];
    
    tmp = sf_get_string(sndfile, SF_STR_DATE);
    if (tmp)
        [string_date        setStringValue: [NSString stringWithCString: tmp]];

    [play_slider setMaxValue: sfinfo.frames];
    [left_channel removeAllItems];
    [right_channel removeAllItems];

    int i;
    for (i=0; i < sfinfo.channels; i++) {
        [left_channel  addItemWithTitle: [NSString stringWithFormat: @"Channel #%d", i]];
        [right_channel addItemWithTitle: [NSString stringWithFormat: @"Channel #%d", i]];
    }
    
    if (sfinfo.channels > 1)
        [right_channel selectItemAtIndex: 1];
    
    lock = [[NSLock alloc] init];
    [self initCoreAudio];
}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
    // Insert code here to write your document from the given data.  You can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.
    
    // For applications targeted for Tiger or later systems, you should use the new Tiger API -dataOfType:error:.  In this case you can also choose to override -writeToURL:ofType:error:, -fileWrapperOfType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.

    return nil;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    *outError = nil;
    
    if (![absoluteURL isFileURL])
        return NO;

    fname = strdup([[absoluteURL path] cString]);

    if (access(fname, R_OK | W_OK) == 0)
        read_only = NO;
    else if (access(fname, R_OK) == 0)
        read_only = YES;
    else {
        printf("permission denied.\n");
        *outError = [NSError errorWithDomain: NSPOSIXErrorDomain code:EPERM userInfo: nil];
        return NO;
    }

    bzero(&sfinfo, sizeof(sfinfo));
    sndfile = sf_open(fname, read_only ? SFM_READ : SFM_RDWR, &sfinfo);
    if (!sndfile)
        return NO;

    return YES;
}

- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError
{
    if (![absoluteURL isFileURL])
        return NO;
    
    if (read_only)
        return NO;

    const char *sname = strdup([[absoluteURL path] cString]);
    if (strcmp(sname, fname) == 0) {
        /* normal save, same file */
        const char *tmp;

        tmp = [[string_title stringValue] cString];
        if (tmp && (strlen(tmp) > 0))
            sf_set_string(sndfile, SF_STR_TITLE, tmp);
        
        tmp = [[string_copyright stringValue] cString];
        if (tmp && (strlen(tmp) > 0))
            sf_set_string(sndfile, SF_STR_COPYRIGHT, tmp);
        
        tmp = [[string_software stringValue] cString];
        if (tmp && (strlen(tmp) > 0))
            sf_set_string(sndfile, SF_STR_SOFTWARE, tmp);
        
        tmp = [[string_artist stringValue] cString];
        if (tmp && (strlen(tmp) > 0))
            sf_set_string(sndfile, SF_STR_ARTIST, tmp);
        
        tmp = [[string_comment stringValue] cString];
        if (tmp && (strlen(tmp) > 0))
            sf_set_string(sndfile, SF_STR_COMMENT, tmp);
        
        tmp = [[string_date stringValue] cString];
        if (tmp && (strlen(tmp) > 0))
            sf_set_string(sndfile, SF_STR_DATE, tmp);

        sf_write_sync(sndfile);

    } else {
        /* "save as" - not yes impl. */
        return NO;
    }

    modified = NO;
    return YES; 
}

- (BOOL)isDocumentEdited
{
    return modified;
}

- (void)close
{
    AudioOutputUnitStop(au_unit);
    [super close];
}

- (IBAction)set_string:(id)sender
{
    if (read_only)
        return;

    modified = YES;
}

- (void)updatePlayPos
{
    sf_count_t current_play_pos = [play_slider intValue];
    [play_pos setStringValue: [NSString stringWithFormat: @"%llu:%02llu:%02llu.%03llu",
                                    (current_play_pos / (sfinfo.samplerate * 60ULL * 60ULL)),
                                    (current_play_pos / (sfinfo.samplerate * 60ULL)) % 60ULL,
                                    (current_play_pos / sfinfo.samplerate) % 60ULL,
                                    ((current_play_pos % sfinfo.samplerate) * 1000ULL) / sfinfo.samplerate ]];
}

- (IBAction)play_slider_moved:(id)sender
{
    [self updatePlayPos];
    buffer_vpos = [sender intValue];
    sf_seek(sndfile, buffer_vpos, SEEK_SET);
    current_buffer_start = 0;
    sf_read_float(sndfile, file_buffer, FILE_BUFFER_SIZE);
}

- (void) timerCallback : (NSTimer *) timer
{
    [self update_buffer];
    [self updatePlayPos];
}

- (IBAction)play:(id)sender
{
    OSStatus err;

    is_playing ^= 1;

    if (is_playing) {
        buffer_vpos = current_buffer_start = 0;
        sf_read_float(sndfile, file_buffer, FILE_BUFFER_SIZE);
        err = AudioOutputUnitStart(au_unit);
        if (err) {
            printf("AudioOutputUnitStart returned %d\n", err);
            return;
        }
        timer = [NSTimer
            timerWithTimeInterval: .1
            target:self selector:@selector(timerCallback:)
            userInfo:nil repeats:YES];

        // add it to the main run loop
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        [play_button setTitle: @"pause"];
    } else {
        err = AudioOutputUnitStop(au_unit);
        if (err) {
            printf("AudioOutputUnitStop returned %d\n", err);
            return;
        }
        [timer invalidate];
        [play_button setTitle: @"play"];
    }
}


@end
