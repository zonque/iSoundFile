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

#define ARRAY_SIZE(a) (sizeof(a)/sizeof(a[0]))

- (NSString *)windowNibName
{
    return @"SoundFile";
}

- (void)initFromSndFile
{
    const char *tmp;

    SF_FORMAT_INFO	format_info;
    format_info.format = sfinfo.format;
    sf_command (sndfile, SFC_GET_FORMAT_INFO, &format_info, sizeof (format_info)) ;

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

    float filesize = (float) file_stat.st_size;
    char pot[] = " KMGT", *c = pot;
    while (filesize > 1024.0) {
        filesize /= 1024.0;
        c++;
    }
    
    snprintf(str, sizeof(str)-1, "%.2f %cB%s", filesize, *c, (*c == ' ') ? "ytes" : "");
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

    int format = sfinfo.format & SF_FORMAT_TYPEMASK;

    /* test whether this file format can handle strings at all */
    if (format != SF_FORMAT_WAV && 
        format != SF_FORMAT_WAVEX &&
        format != SF_FORMAT_AIFF &&
        format != SF_FORMAT_FLAC &&
        format != SF_FORMAT_CAF) {
        NSTabViewItem *tab = [tabView tabViewItemAtIndex: [tabView indexOfTabViewItemWithIdentifier: @"Strings"]];
        [tabView removeTabViewItem: tab];
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
    
    if (format != SF_FORMAT_WAV && format != SF_FORMAT_WAVEX) {
        NSTabViewItem *tab = [tabView tabViewItemAtIndex: [tabView indexOfTabViewItemWithIdentifier: @"BEXT"]];
        [tabView removeTabViewItem: tab];
    }

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

    /* Peak */
    peakTableSource = [[ChannelTableSource alloc] init];
    [peakTableSource setNumChannels: sfinfo.channels];
    [peakTableSource setType: PEAK_TABLE];
    [peakTable setHidden: TRUE];

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
        *outError = [NSError errorWithDomain: @"libsndfileError" code:-1
                    userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithCString: err], NSLocalizedDescriptionKey, nil]];

        return NO;
    }
    
    stat(fname, &file_stat);
    modified = NO;
    
    return YES;
}

- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError
{
    *outError = nil;
    
    if (![absoluteURL isFileURL])
        return NO;
        
    memcpy(&convertSFInfo, &sfinfo, sizeof(sfinfo));
    BOOL ret = [self convertToURL: absoluteURL 
                     calledFromConvert: NO];
    
    if (ret && saveOperation == NSSaveOperation)
        modified = NO;

    return ret;
}

- (BOOL)isDocumentEdited
{
    return modified;
}

- (void)close
{
    if (audioRenderer) {
        [audioRenderer release];
        audioRenderer = nil;
    }
    
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

- (void)controlTextDidChange:(NSNotification *)aNotification
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
    isPlaying ^= 1;

    if (isPlaying) {
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

    h = strtol(sh, NULL, 10);
    m = strtol(sm, NULL, 10);
    s = strtol(ss, NULL, 10);
    samp = strtol(ssamp, NULL, 10);

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

- (BOOL) convertToURL:(NSURL *) newURL calledFromConvert: (BOOL) calledFromConvert
{
    SNDFILE *outfile;

    bool isSameFile = [[newURL path] isEqualToString: [[self fileURL] path]];

    char tmpfname[0x100];
    const char *tmp;
    const char *newName;
    
    if (isSameFile) {
        snprintf(tmpfname, sizeof(tmpfname)-1, "/tmp/isoundfile-%p-%08x", self, [[[self fileURL] path] hash]);
        newName = tmpfname;
    } else
        newName = [[newURL path] cString];

    outfile = sf_open(newName, SFM_WRITE, &convertSFInfo);
    if (!outfile) {
		NSAlert *alertSheet = [[NSAlert alloc] init];
		[alertSheet addButtonWithTitle:@"Exit"];
		[alertSheet setAlertStyle:NSCriticalAlertStyle];

		[alertSheet setMessageText:@"Unable to write file"];
		[alertSheet setInformativeText: [NSString stringWithCString: sf_strerror(NULL)]];
		[alertSheet beginSheetModalForWindow:[self windowForSheet] modalDelegate:self didEndSelector: @selector(sheetReleaser:) contextInfo:nil];
        return NO;
    }

    [convertProgress setIndeterminate: NO];
    [NSApp beginSheet:convertSheet modalForWindow: [self windowForSheet]
                        modalDelegate:self 
                        didEndSelector:nil 
                        contextInfo:NULL];

    NSModalSession session = [NSApp beginModalSessionForWindow:[self windowForSheet]];

    [audioRenderer pause];
    sf_seek(sndfile, 0, SEEK_SET);

    BOOL writeBext = NO;

    if (!calledFromConvert)
        if ([[bextDescription stringValue] length] != 0 ||
            [[bextCodingHistory stringValue] length] != 0 ||
            [[bextOriginationDate stringValue] length] != 0 ||
            [[bextOriginationTime stringValue] length] != 0 ||
            [[bextOriginator stringValue] length] != 0 ||
            [[bextOriginatorRef stringValue] length] != 0 ||
            [[bextUMID stringValue] length] != 0 ||
            [[bextTimecode stringValue] length] != 0)
            writeBext = YES;

    if (calledFromConvert && ([convertKeepBEXT state] == NSOnState))
        writeBext = YES;

    if (writeBext) {
        [self bextUpdateTimecode: bextTimecode];
        sf_command(outfile, SFC_SET_BROADCAST_INFO, &bext, sizeof(bext));
    }
    
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

    sf_count_t framesWritten = 0, foo=0;

    int i, n, buf[1 << 16];
    
    while ((n = sf_read_int(sndfile, buf, ARRAY_SIZE(buf)))) {
        if (sfinfo.channels == convertSFInfo.channels)
            sf_write_int(outfile, buf, n);
        else {
            for (i=0; i < n; i++)
                if ([convertTableSource channelIsSelected: i % sfinfo.channels])
                    sf_write_int(outfile, buf + i, 1);
        }
        
        framesWritten += n / sfinfo.channels;
        [convertProgress setDoubleValue: ((double) framesWritten * 100) / (double) sfinfo.frames];
        [NSApp runModalSession:session];
    }
    
    sf_close(outfile);

    if (isSameFile) {
        sf_close(sndfile);
        rename(newName, [[newURL path] cString]);
        bzero(&sfinfo, sizeof(sfinfo));
        sndfile = sf_open([[newURL path] cString], SFM_READ, &sfinfo);
        [self initFromSndFile];
        [self setFileURL: newURL];
    } else if (calledFromConvert) {
        NSDocumentController *controller = [NSDocumentController sharedDocumentController];
        NSError *err;
        NSDocument *doc = [controller openDocumentWithContentsOfURL: newURL
                            display: YES
                            error: &err];
        [[doc windowForSheet] makeKeyAndOrderFront: self];
    }

    [NSApp endModalSession:session];
    [convertSheet orderOut: self];
    [NSApp endSheet:convertSheet returnCode:0];
    
    return YES;
}

- (void)convertFileNameChosen:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];

    if (returnCode == 0)
        return;

    [self convertToURL: [sheet URL] calledFromConvert: YES];
}

- (IBAction) convertCancel: (id) sender
{
    [convertSheet orderOut: self];
    [NSApp endSheet:convertSheet returnCode:0];
}

- (IBAction) convert: (id) sender
{
    SF_FORMAT_INFO tmp_format_info;
    NSSavePanel *panel = [NSSavePanel savePanel];
    char *name = strdup([[[self fileURL] path] cString]);
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

    [panel beginSheetForDirectory: [[self fileURL] path] file: [NSString stringWithCString: tmp]
                modalForWindow: [self windowForSheet]
                modalDelegate:self 
                didEndSelector:@selector(convertFileNameChosen:returnCode:contextInfo:)
                contextInfo:nil];

    [NSApp beginSheet:[NSSavePanel savePanel] modalForWindow: [self windowForSheet]
                        modalDelegate:self 
                        didEndSelector:@selector(convertSheetDidEnd:returnCode:contextInfo:) 
                        contextInfo:NULL];

    free(name);
}

- (IBAction) calculatePeak: (id) sender
{
    sf_count_t playSave, framesRead = 0;
    
    [peakProgress setHidden: FALSE];
    [peakProgress setIndeterminate: FALSE];
    [sender setHidden: TRUE];
    [peakTableSource setSFinfo: &sfinfo];

    BOOL wasPlaying = isPlaying;
    if (isPlaying) {
        playSave = [playSlider intValue];
        [self play: self];
    }

    NSModalSession session = [NSApp beginModalSessionForWindow:[self windowForSheet]];
    
    int save_state = sf_command(sndfile, SFC_GET_NORM_DOUBLE, NULL, 0);
    sf_command(sndfile, SFC_SET_NORM_DOUBLE, NULL, SF_FALSE);
    
    int c, n;
    sf_seek(sndfile, 0, SEEK_SET);

    double buf[1 << 16];
    while((n = sf_read_double(sndfile, buf, ARRAY_SIZE(buf)))) {        
        framesRead += n;

        for (c = 0; c < n; c++) {
            int chn = c % sfinfo.channels;
            [peakTableSource setPeakIfHigher: fabs(buf[c]) channel: chn];
        }

        [peakProgress setDoubleValue: ((double) framesRead * 100) / (double) (sfinfo.frames * sfinfo.channels)];
        if ([NSApp runModalSession:session] != NSRunContinuesResponse)
            {}; //break;
    }

    sf_command(sndfile, SFC_SET_NORM_DOUBLE, NULL, save_state);

    [NSApp endModalSession:session];
    [peakProgress setHidden: TRUE];
    [peakNotYet setHidden: TRUE];
    [peakTable setDataSource: peakTableSource];
    [peakTable setHidden: FALSE];
    [peakTable reloadData];

    if (wasPlaying) {
        [playSlider setIntValue: playSave];
        [self playSliderMoved: playSlider];
        [self play: self];
    }
}

- (IBAction) eof: (id)sender
{
    [self play: nil];
    [playSlider setIntValue: 0];
    [self playSliderMoved: playSlider];
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
    [savePanel setAllowsOtherFileTypes: NO];
    [savePanel setExtensionHidden: NO];
    return YES;
}

- (NSArray *)writableTypesForSaveOperation:(NSSaveOperationType)saveOperation
{
    return [NSArray arrayWithObject: [self fileType]];
}

@end
