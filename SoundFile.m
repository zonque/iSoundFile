#include <unistd.h>

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
