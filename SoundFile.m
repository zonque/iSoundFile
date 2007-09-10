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
#import "ChannelTableSource.h"
#import "AudioRenderer.h"
#import "SoundFile.h"

@implementation SoundFile


- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"SoundFile";
}

- (void)initFromSndFile
{
    const char *tmp;

    SF_FORMAT_INFO	format_info;
    format_info.format = sfinfo.format;
    sf_command (sndfile, SFC_GET_FORMAT_INFO, &format_info, sizeof (format_info)) ;

    if (format_info.name == NULL) {
        [self close];
        return;
    }

    [labelFormat setStringValue: [NSString stringWithCString: format_info.name]];

    format_info.format = sfinfo.format & SF_FORMAT_SUBMASK;
    sf_command (sndfile, SFC_GET_FORMAT_INFO, &format_info, sizeof (format_info)) ;
    [labelSampleFormat setStringValue: [NSString stringWithCString: format_info.name]];

    [labelSamplerate setIntValue: sfinfo.samplerate];
    [labelChannels setIntValue: sfinfo.channels];
    [labelFrames setIntValue: sfinfo.frames];
    [labelSections setIntValue: sfinfo.sections];

    char str[128];
    int seconds = sfinfo.frames / sfinfo.samplerate ;

    snprintf (str, sizeof (str) - 1, "%02d:", seconds / 60 / 60) ;
    
    seconds = seconds % (60 * 60) ;
    snprintf (str + strlen (str), sizeof (str) - strlen (str) - 1, "%02d:", seconds / 60) ;

    seconds = seconds % 60 ;
    snprintf (str + strlen (str), sizeof (str) - strlen (str) - 1, "%02d.", seconds) ;

    seconds = ((1000 * sfinfo.frames) / sfinfo.samplerate) % 1000 ;
    snprintf (str + strlen (str), sizeof (str) - strlen (str) - 1, "%03d", seconds) ;
    
    [labelLength setStringValue: [NSString stringWithCString: str]];

    off_t filesize = file_stat.st_size;
    char pot[] = " KMGT", *c = pot;
    while (filesize > 1024ULL) {
        filesize /= 1024ULL;
        c++;
    }
    
    snprintf(str, sizeof(str)-1, "%llu %c%s", filesize, *c, (*c == ' ') ? "ytes" : "");
    [labelFilesize setStringValue: [NSString stringWithCString: str]];

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
        case SF_FORMAT_DOUBLE:
            bit_depth = 32;
            break;
    }
    
    if (bit_depth > 0) {
        [labelBytesPerSample setIntValue: bit_depth / 8];
        [labelBytesPerSecond setIntValue: (bit_depth / 8) * sfinfo.samplerate * sfinfo.channels];
    } else {
        [labelBytesPerSample setStringValue: @"unknown"];
        [labelBytesPerSecond setStringValue: @"unknown"];
    }
    
    if (read_only) {
        [stringTitle setEnabled: NO];
        [stringCopyright setEnabled: NO];
        [stringSoftware setEnabled: NO];
        [stringArtist setEnabled: NO];
        [stringComment setEnabled: NO];
        [stringDate setEnabled: NO];
    }

    tmp = sf_get_string(sndfile, SF_STR_TITLE);
    if (tmp)
        [stringTitle       setStringValue: [NSString stringWithCString: tmp]];

    tmp = sf_get_string(sndfile, SF_STR_COPYRIGHT);
    if (tmp)
        [stringCopyright   setStringValue: [NSString stringWithCString: tmp]];

    tmp = sf_get_string(sndfile, SF_STR_SOFTWARE);
    if (tmp)
        [stringSoftware    setStringValue: [NSString stringWithCString: tmp]];
    
    tmp = sf_get_string(sndfile, SF_STR_ARTIST);
    if (tmp)
        [stringArtist      setStringValue: [NSString stringWithCString: tmp]];
    
    tmp = sf_get_string(sndfile, SF_STR_COMMENT);
    if (tmp)
        [stringComment     setStringValue: [NSString stringWithCString: tmp]];
    
    tmp = sf_get_string(sndfile, SF_STR_DATE);
    if (tmp)
        [stringDate        setStringValue: [NSString stringWithCString: tmp]];

    BOOL got_bext = sf_command (sndfile, SFC_GET_BROADCAST_INFO, &bext, sizeof (bext));
    if (got_bext) {
        [bextVersion           setIntValue: bext.version];
        [bextDescription       setStringValue: [NSString stringWithCString: bext.description]];
        [bextOriginator        setStringValue: [NSString stringWithCString: bext.originator]];
        [bextOriginatorRef     setStringValue: [NSString stringWithCString: bext.originator_reference]];
        [bextOriginationDate   setStringValue: [NSString stringWithCString: bext.origination_date]];
        [bextOriginationTime   setStringValue: [NSString stringWithCString: bext.origination_time]];
        [bextUMID              setStringValue: [NSString stringWithCString: bext.umid]];
        [bextCodingHistory     setStringValue: [NSString stringWithCString: bext.coding_history]];
        [self bextUpdateTimecodeFromFile];
        [convertKeepBEXT setEnabled: YES];
        [convertKeepBEXT setState: NSOnState];
    } else {
        [bextVersion setEnabled: FALSE];
        [bextDescription setEnabled: FALSE];
        [bextOriginator setEnabled: FALSE];
        [bextOriginatorRef setEnabled: FALSE];
        [bextOriginationDate setEnabled: FALSE];
        [bextOriginationTime setEnabled: FALSE];
        [bextUMID setEnabled: FALSE];
        [bextCodingHistory setEnabled: FALSE];
        [bextTimecode setEnabled: FALSE];
        [convertKeepBEXT setEnabled: NO];
        [convertKeepBEXT setState: NSOffState];
    }

    /* Convert tab */
    int major_count, subtype_count, selected_format = 0, m;
    sf_command (NULL, SFC_GET_FORMAT_MAJOR_COUNT, &major_count, sizeof (int)) ;
    sf_command (NULL, SFC_GET_FORMAT_SUBTYPE_COUNT, &subtype_count, sizeof (int)) ;

    [convertFormat removeAllItems];

    for (m = 0 ; m < major_count ; m++) {
        format_info.format = m;
        sf_command (NULL, SFC_GET_FORMAT_MAJOR, &format_info, sizeof (format_info));
        [convertFormat addItemWithTitle: [NSString stringWithCString: format_info.name]];
        
        if ((sfinfo.format & SF_FORMAT_TYPEMASK) == format_info.format)
            selected_format = m;
    }
    
    [convertFormat selectItemAtIndex: selected_format];
    [self convertFormatSelected: convertFormat];
    
    
    convertTableSource = [[ChannelTableSource alloc] init];
    [convertTableSource setNumChannels: sfinfo.channels];
    [convertTable setDataSource: convertTableSource];
        
    /* Playback */
    [playSlider setMaxValue: sfinfo.frames];
    [leftChannel removeAllItems];
    [rightChannel removeAllItems];

    int i;
    for (i=0; i < sfinfo.channels; i++) {
        [leftChannel  addItemWithTitle: [NSString stringWithFormat: @"Channel #%d", i]];
        [rightChannel addItemWithTitle: [NSString stringWithFormat: @"Channel #%d", i]];
    }
    
    if (sfinfo.channels > 1)
        [rightChannel selectItemAtIndex: 1];

    audioRenderer = [[AudioRenderer alloc] init];
    [audioRenderer set_sndfile: sndfile : &sfinfo];

    [audioRenderer setLeftOutputMapping:  [leftChannel indexOfSelectedItem]];
    [audioRenderer setRightOutputMapping: [rightChannel indexOfSelectedItem]];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(filePositionChanged:)
		name:@"filePositionChanged" object:audioRenderer];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(eof:)
		name:@"EOF" object:audioRenderer];
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.

    [self initFromSndFile];
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
    
    url = [absoluteURL copy];
    stat(fname, &file_stat);
    
    return YES;
}

- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError
{
    if (![absoluteURL isFileURL])
        return NO;
    
    if (read_only)
        return NO;

    if (saveOperation == NSSaveOperation) {
        /* normal save, same file */
        const char *tmp;

        tmp = [[stringTitle stringValue] cString];
        if (tmp && (strlen(tmp) > 0))
            sf_set_string(sndfile, SF_STR_TITLE, tmp);
        
        tmp = [[stringCopyright stringValue] cString];
        if (tmp && (strlen(tmp) > 0))
            sf_set_string(sndfile, SF_STR_COPYRIGHT, tmp);
        
        tmp = [[stringSoftware stringValue] cString];
        if (tmp && (strlen(tmp) > 0))
            sf_set_string(sndfile, SF_STR_SOFTWARE, tmp);
        
        tmp = [[stringArtist stringValue] cString];
        if (tmp && (strlen(tmp) > 0))
            sf_set_string(sndfile, SF_STR_ARTIST, tmp);
        
        tmp = [[stringComment stringValue] cString];
        if (tmp && (strlen(tmp) > 0))
            sf_set_string(sndfile, SF_STR_COMMENT, tmp);
        
        tmp = [[stringDate stringValue] cString];
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
    
    if (url) {
        [url release];
        url = nil;
    }
    
    [super close];
}

- (IBAction)setString:(id)sender
{
    modified = YES;
}

- (void)updatePlayPos
{
    sf_count_t current_play_pos = [playSlider intValue];
    [playPos setStringValue: [NSString stringWithFormat: @"%llu:%02llu:%02llu.%03llu",
                                    (current_play_pos / (sfinfo.samplerate * 60ULL * 60ULL)),
                                    (current_play_pos / (sfinfo.samplerate * 60ULL)) % 60ULL,
                                    (current_play_pos / sfinfo.samplerate) % 60ULL,
                                    ((current_play_pos % sfinfo.samplerate) * 1000ULL) / sfinfo.samplerate ]];
}

- (IBAction)playSliderMoved:(id)sender
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
        [playButton setTitle: @"pause"];
    } else {
        [audioRenderer pause];
        if (timer) {
            [timer invalidate];
            timer = nil;
        }
        
        [playButton setTitle: @"play"];
    }
}

- (IBAction) bextUpdateTimecodeFromFile
{
    UInt64 tc, s, f;
        
    tc = bext.time_reference_high;
    tc <<= 32;
    tc |= bext.time_reference_low;
    
    s = tc / sfinfo.samplerate;
    f = tc % sfinfo.samplerate;
    [bextTimecode setStringValue: [NSString stringWithFormat: @"%03llu:%02llu:%02llu:%llu", s/3600, (s/60) % 60, s % 60, f]];
}

- (IBAction) bextUpdateTimecode: (id) sender
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

- (IBAction) convertFormatSelected: (id) sender
{
    SF_FORMAT_INFO info;
    SF_INFO tmp_sfinfo;
    int s, format = [sender indexOfSelectedItem];
    int subtype_count;
    
    memset (&tmp_sfinfo, 0, sizeof(tmp_sfinfo)) ;
    tmp_sfinfo.channels = 1;
    
    sf_command (NULL, SFC_GET_FORMAT_SUBTYPE_COUNT, &subtype_count, sizeof(int));
    [convertSubformat removeAllItems];

    info.format = format;
    sf_command (NULL, SFC_GET_FORMAT_MAJOR, &info, sizeof (info));
    format = info.format;

    for (s = 0 ; s < subtype_count ; s++) {
        info.format = s;
        sf_command (NULL, SFC_GET_FORMAT_SUBTYPE, &info, sizeof (info));
                
        format = (format & SF_FORMAT_TYPEMASK) | info.format;
        
        tmp_sfinfo.format = format;
        if (sf_format_check(&tmp_sfinfo)) {
            [convertSubformat addItemWithTitle: [NSString stringWithCString: info.name]];
            convertFormats[[convertSubformat numberOfItems] - 1] = format;
        }
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
    [playSlider setIntValue: [audioRenderer currentPosition]];
}

- (void)sheetReleaser:(NSWindow *)sheet
{
    [sheet release];
}

- (void)convertFileNameChosen:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    SNDFILE *outfile;
    
    [sheet orderOut:self];

    if (returnCode == 0)
        return;

    bool isSameFile = [[[sheet URL] path] isEqualToString: [url path]];

    char tmpfname[0x100];
    const char *tmp;
    const char *newName;
    
    if (isSameFile) {
        snprintf(tmpfname, sizeof(tmpfname)-1, "/tmp/isoundfile-%p-%08x", self, [[url path] hash]);
        newName = tmpfname;
    } else
        newName = [[sheet filename] cString];

    outfile = sf_open(newName, SFM_WRITE, &convertSFInfo);
    if (!outfile) {
		NSAlert *alertSheet = [[NSAlert alloc] init];
		[alertSheet addButtonWithTitle:@"Exit"];
		[alertSheet setAlertStyle:NSCriticalAlertStyle];

		[alertSheet setMessageText:@"Unable to write file"];
		[alertSheet setInformativeText: [NSString stringWithCString: sf_strerror(NULL)]];
		[alertSheet beginSheetModalForWindow:[self windowForSheet] modalDelegate:self didEndSelector: @selector(sheetReleaser:) contextInfo:nil];
        return;
    }

    [convertProgress setIndeterminate: NO];
    [NSApp beginSheet:convertSheet modalForWindow: [self windowForSheet]
                        modalDelegate:self 
                        didEndSelector:nil 
                        contextInfo:NULL];

    NSModalSession session = [NSApp beginModalSessionForWindow:[self windowForSheet]];

    [audioRenderer pause];
    sf_seek(sndfile, 0, SEEK_SET);

    if ([convertKeepBEXT state] == NSOnState)
        sf_command(outfile, SFC_SET_BROADCAST_INFO, &bext, sizeof(bext));

    tmp = [[stringTitle stringValue] cString];
    if (tmp && (strlen(tmp) > 0))
        sf_set_string(outfile, SF_STR_TITLE, tmp);
    
    tmp = [[stringCopyright stringValue] cString];
    if (tmp && (strlen(tmp) > 0))
        sf_set_string(outfile, SF_STR_COPYRIGHT, tmp);
    
    tmp = [[stringSoftware stringValue] cString];
    if (tmp && (strlen(tmp) > 0))
        sf_set_string(outfile, SF_STR_SOFTWARE, tmp);
    
    tmp = [[stringArtist stringValue] cString];
    if (tmp && (strlen(tmp) > 0))
        sf_set_string(outfile, SF_STR_ARTIST, tmp);
    
    tmp = [[stringComment stringValue] cString];
    if (tmp && (strlen(tmp) > 0))
        sf_set_string(outfile, SF_STR_COMMENT, tmp);
    
    tmp = [[stringDate stringValue] cString];
    if (tmp && (strlen(tmp) > 0))
        sf_set_string(outfile, SF_STR_DATE, tmp);

    sf_count_t framesWritten = 0;
    while (framesWritten < sfinfo.frames) {
        int i, buf[1024*8];
        int thisTime = sfinfo.frames - framesWritten;
        if (thisTime > sizeof(buf) / sizeof(buf[0]))
            thisTime = sizeof(buf) / sizeof(buf[0]);
        
        if (thisTime < sfinfo.channels)
            break;
        
        sf_read_int(sndfile, buf, thisTime);
        
        if (sfinfo.channels != convertSFInfo.channels) {
            for (i = 0; i < thisTime; i++) {
                if ([convertTableSource channelIsSelected: i % sfinfo.channels])
                    sf_write_int(outfile, buf + i, 1);
            }
        } else
            sf_write_int(outfile, buf, thisTime);

        framesWritten += (sf_count_t) thisTime / (sf_count_t) sfinfo.channels;
        [convertProgress setDoubleValue: ((double) framesWritten * 100) / (double) sfinfo.frames];
        
        if ([NSApp runModalSession:session] != NSRunContinuesResponse)
            break;
    }
    
    sf_close(outfile);

    if (isSameFile) {
        sf_close(sndfile);
        rename(newName, [[sheet filename] cString]);
        bzero(&sfinfo, sizeof(sfinfo));
        sndfile = sf_open([[sheet filename] cString], SFM_READ, &sfinfo);
        [self initFromSndFile];
    }

    [NSApp endModalSession:session];
    [convertSheet orderOut: self];
    [NSApp endSheet:convertSheet returnCode:0];
}

- (IBAction) convertCancel: (id) sender
{
    [convertSheet orderOut: self];
    [NSApp endSheet:convertSheet returnCode:0];
}

- (void) convertProgressUpdate
{

}

- (IBAction) convert: (id) sender
{
    SF_FORMAT_INFO tmp_format_info;
    NSSavePanel *panel = [NSSavePanel savePanel];
    char *name = strdup([[url path] cString]);
    char *newname = name;
    int i;
    
    char *c = strrchr(newname, '/');
    if (c)
        newname = ++c;
    
    c = strrchr(newname, '.');
    if (c)
        *c = '\0';

    int format = convertFormats[[convertSubformat indexOfSelectedItem]];

    memcpy(&convertSFInfo, &sfinfo, sizeof(sfinfo));

    convertSFInfo.format = format;
    convertSFInfo.channels = 0;
    
    for (i = 0; i < sfinfo.channels; i++)
        if ([convertTableSource channelIsSelected: i])
            convertSFInfo.channels++;

    bzero(&tmp_format_info, sizeof(tmp_format_info));
    tmp_format_info.format = [convertFormat indexOfSelectedItem];
    sf_command (NULL, SFC_GET_FORMAT_MAJOR, &tmp_format_info, sizeof (tmp_format_info));
    tmp_format_info.format = format;
    
    char tmp[0x100];
    snprintf(tmp, sizeof(tmp) - 1, "%s.%s", newname, tmp_format_info.extension);
    free(name);

    [panel beginSheetForDirectory: [url path] file: [NSString stringWithCString: tmp]
                modalForWindow: [self windowForSheet]
                modalDelegate:self 
                didEndSelector:@selector(convertFileNameChosen:returnCode:contextInfo:)
                contextInfo:nil];

    [NSApp beginSheet:[NSSavePanel savePanel] modalForWindow: [self windowForSheet]
                        modalDelegate:self 
                        didEndSelector:@selector(convertSheetDidEnd:returnCode:contextInfo:) 
                        contextInfo:NULL];
}

- (IBAction) eof: (id)sender
{
    [self play: nil];
    [playSlider setIntValue: 0];
    [self playSliderMoved: playSlider];
}


@end
