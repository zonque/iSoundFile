#include <unistd.h>

#import <sndfile.h>
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

- (IBAction)set_string:(id)sender
{
    if (read_only)
        return;

    modified = YES;
}


@end
