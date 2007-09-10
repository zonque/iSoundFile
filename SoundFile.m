#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

#import <CoreAudio/CoreAudio.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <AudioUnit/AUComponent.h>
#import <AudioUnit/AudioOutputUnit.h>
#import <AudioUnit/AudioUnitProperties.h>
#import <AudioUnit/AudioUnitParameters.h>

#import <sndfile.h>
#import "AudioRenderer.h"
#import "SoundFile.h"

@implementation SoundFile


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

    format_info.format = sfinfo.format & SF_FORMAT_SUBMASK;
    sf_command (sndfile, SFC_GET_FORMAT_INFO, &format_info, sizeof (format_info)) ;
    [label_sample_format setStringValue: [NSString stringWithCString: format_info.name]];

    [label_samplerate setIntValue: sfinfo.samplerate];
    [label_channels setIntValue: sfinfo.channels];
    [label_frames setIntValue: sfinfo.frames];
    [label_sections setIntValue: sfinfo.sections];

    char str[128];
    int seconds = sfinfo.frames / sfinfo.samplerate ;

    snprintf (str, sizeof (str) - 1, "%02d:", seconds / 60 / 60) ;
    
    seconds = seconds % (60 * 60) ;
    snprintf (str + strlen (str), sizeof (str) - strlen (str) - 1, "%02d:", seconds / 60) ;

    seconds = seconds % 60 ;
    snprintf (str + strlen (str), sizeof (str) - strlen (str) - 1, "%02d.", seconds) ;

    seconds = ((1000 * sfinfo.frames) / sfinfo.samplerate) % 1000 ;
    snprintf (str + strlen (str), sizeof (str) - strlen (str) - 1, "%03d", seconds) ;
    
    [label_length setStringValue: [NSString stringWithCString: str]];

    off_t filesize = file_stat.st_size;
    char pot[] = " KMGT", *c = pot;
    while (filesize > 1024ULL) {
        filesize /= 1024ULL;
        c++;
    }
    
    snprintf(str, sizeof(str)-1, "%llu %c%s", filesize, *c, (*c == ' ') ? "ytes" : "");
    [label_filesize setStringValue: [NSString stringWithCString: str]];

    int bit_depth = -1;

    switch(sfinfo.format & SF_FORMAT_SUBMASK) {
        case SF_FORMAT_PCM_S8:
        case SF_FORMAT_PCM_U8:
        case SF_FORMAT_DPCM_8:
            bit_depth = 8;
            break;
        case SF_FORMAT_DWVW_12:
            bit_depth = 12;
            break;
        case SF_FORMAT_PCM_16:
        case SF_FORMAT_DWVW_16:
        case SF_FORMAT_DPCM_16:
            bit_depth = 16;
            break;
        case SF_FORMAT_PCM_24:
        case SF_FORMAT_DWVW_24:
            bit_depth = 24;
            break;
        case SF_FORMAT_PCM_32:
        case SF_FORMAT_FLOAT:
            bit_depth = 32;
            break;
        case SF_FORMAT_DOUBLE:
            bit_depth = 64;
            break;
    }
    
    if (bit_depth > 0) {
        [label_bytes_per_sample setIntValue: bit_depth / 8];
        [label_bytes_per_second setIntValue: (bit_depth / 8) * sfinfo.samplerate * sfinfo.channels];
    } else {
        [label_bytes_per_sample setStringValue: @"unknown"];
        [label_bytes_per_second setStringValue: @"unknown"];
    }
    
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

    BOOL got_bext = sf_command (sndfile, SFC_GET_BROADCAST_INFO, &bext, sizeof (bext));
    if (got_bext) {
        [bext_version           setIntValue: bext.version];
        [bext_description       setStringValue: [NSString stringWithCString: bext.description]];
        [bext_originator        setStringValue: [NSString stringWithCString: bext.originator]];
        [bext_originator_ref    setStringValue: [NSString stringWithCString: bext.originator_reference]];
        [bext_origination_date  setStringValue: [NSString stringWithCString: bext.origination_date]];
        [bext_origination_time  setStringValue: [NSString stringWithCString: bext.origination_time]];
        [bext_UMID              setStringValue: [NSString stringWithCString: bext.umid]];
        [bext_coding_history    setStringValue: [NSString stringWithCString: bext.coding_history]];
        [self bext_update_timecode_fps: bext_timecode_fps];
    } else {
        [bext_version setEnabled: FALSE];
        [bext_description setEnabled: FALSE];
        [bext_originator setEnabled: FALSE];
        [bext_originator_ref setEnabled: FALSE];
        [bext_origination_date setEnabled: FALSE];
        [bext_origination_time setEnabled: FALSE];
        [bext_UMID setEnabled: FALSE];
        [bext_coding_history setEnabled: FALSE];
        [bext_timecode setEnabled: FALSE];
        [bext_timecode_fps setEnabled: FALSE];
    }

   
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

    audioRenderer = [[AudioRenderer alloc] init];
    [audioRenderer set_sndfile: sndfile : &sfinfo];

    [audioRenderer setLeftOutputMapping:  [left_channel indexOfSelectedItem]];
    [audioRenderer setRightOutputMapping: [right_channel indexOfSelectedItem]];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(filePositionChanged:)
		name:@"filePositionChanged" object:audioRenderer];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(eof:)
		name:@"EOF" object:audioRenderer];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    *outError = nil;
    
    if (![absoluteURL isFileURL])
        return NO;

    fname = strdup([[absoluteURL path] cString]);

    bzero(&sfinfo, sizeof(sfinfo));
    sndfile = sf_open(fname, SFM_READ, &sfinfo);
    
    if (!sndfile) {
        char err[0x100];
        sf_error_str(sndfile, err, sizeof(err));
        printf ("fname = >%s< err = >%s<\n", fname, err);
//        *outError = [NSError errorWithDomain: @"libsndfileError" code:-1
//                    userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithCString: err], NSLocalizedDescriptionKey, nil]];
        *outError = [NSError errorWithDomain:@"fun house errors" code:-10101
          userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"problems creating image destination for file save", NSLocalizedDescriptionKey, nil]];

        return NO;
    }
    
    stat(fname, &file_stat);
    
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
        sf_command(sndfile, SFC_UPDATE_HEADER_NOW, NULL, 0);
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
    [audioRenderer release];
    
    if (timer) {
        [timer invalidate];
        timer = nil;
    }
    
    if (sndfile) {
        sf_close(sndfile);
        sndfile = nil;
    }
    
    [super close];
}

- (IBAction)set_string:(id)sender
{
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
    [audioRenderer seek: [sender intValue]];
}

- (void) timerCallback : (NSTimer *) timer
{
    [audioRenderer update_buffer];
    [self updatePlayPos];
}

- (IBAction)play:(id)sender
{
    is_playing ^= 1;

    if (is_playing) {
        timer = [NSTimer
            timerWithTimeInterval: .1
            target:self selector:@selector(timerCallback:)
            userInfo:nil repeats:YES];

        [audioRenderer play];

        // add it to the main run loop
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        [play_button setTitle: @"pause"];
    } else {
        [audioRenderer pause];
        if (timer) {
            [timer invalidate];
            timer = nil;
        }
        
        [play_button setTitle: @"play"];
    }
}

- (int) getTimecodeSPF
{
    int spf = -1;
    
    switch ([bext_timecode_fps indexOfSelectedItem]) {
        case 0: /* 25 fps */
            spf = sfinfo.samplerate / 25;
            break;
        case 1: /* 24 fps */
            spf = sfinfo.samplerate / 24;
            break;
    }

    return spf;
}

- (IBAction) bext_update_timecode_fps: (id) sender
{
    UInt64 tc, s, f;
        
    tc = bext.time_reference_high;
    tc <<= 32;
    tc |= bext.time_reference_low;
    
    s = tc / sfinfo.samplerate;
    f = tc % sfinfo.samplerate;
    [bext_timecode setStringValue: [NSString stringWithFormat: @"%03llu:%02llu:%02llu:%llu", s/3600, (s/60) % 60, s % 60, f]];
}

- (IBAction) bext_update_timecode: (id) sender
{
    char tmp[0x100], *sh, *sm, *ss, *ssamp;
    int h, m, s, samp;

    [[sender stringValue] getCString: tmp maxLength: sizeof(tmp) encoding: NSASCIIStringEncoding];
    sh = strtok(tmp, ":");
    sm = strtok(NULL, ":");
    ss = strtok(NULL, ":");
    ssamp = strtok(NULL, ":");
    
    if (!sh || !sm || !ss || !ssamp)
        return;

    h = strtol(sh, NULL, 0);
    m = strtol(sm, NULL, 0);
    s = strtol(ss, NULL, 0);
    samp = strtol(ssamp, NULL, 0);

    s += (h * 3600 + m * 60);

    UInt64 tc = (UInt64) s * (UInt64) sfinfo.samplerate + (UInt64) samp;
    bext.time_reference_low = tc & 0xffffffff;
    bext.time_reference_high = tc >> 32;
}


- (IBAction) setOutputMapping: (id) sender
{
    if ([sender tag] == 0)
        [audioRenderer setLeftOutputMapping: [sender indexOfSelectedItem]];
    else
        [audioRenderer setRightOutputMapping: [sender indexOfSelectedItem]];
}

- (IBAction) filePositionChanged: (id) sender
{
    [play_slider setIntValue: [audioRenderer currentPosition]];
}

- (IBAction) eof: (id)sender
{
    [self play: nil];
    [play_slider setIntValue: 0];
    [self play_slider_moved: play_slider];
}


@end
