/* SoundFile */

#import <Cocoa/Cocoa.h>

@interface SoundFile : NSDocument
{
    SNDFILE *sndfile;
    SF_INFO  sfinfo;
    SF_INFO convertSFInfo;
    SF_BROADCAST_INFO bext;
    BOOL read_only, modified;
    BOOL is_playing;
    const char *fname;
    NSTimer *timer;
    AudioRenderer *audioRenderer;
    struct stat file_stat;
    NSURL *url;
    int convertFormats[0x100];
        ChannelTableSource *convertTableSource;

    IBOutlet NSWindow *window;

    IBOutlet NSTextField *stringArtist;
    IBOutlet NSTextField *stringComment;
    IBOutlet NSTextField *stringCopyright;
    IBOutlet NSTextField *stringDate;
    IBOutlet NSTextField *stringSoftware;
    IBOutlet NSTextField *stringTitle;

    IBOutlet NSTextField *labelFormat;
    IBOutlet NSTextField *labelSamplerate;
    IBOutlet NSTextField *labelBytesPerSample;
    IBOutlet NSTextField *labelChannels;
    IBOutlet NSTextField *labelFrames;
    IBOutlet NSTextField *labelLength;
    IBOutlet NSTextField *labelFilesize;
    IBOutlet NSTextField *labelBytesPerSecond;
    IBOutlet NSTextField *labelSampleFormat;
    IBOutlet NSTextField *labelSections;

    IBOutlet NSTextField *bextCodingHistory;
    IBOutlet NSTextField *bextDescription;
    IBOutlet NSTextField *bextOriginationDate;
    IBOutlet NSTextField *bextOriginationTime;
    IBOutlet NSTextField *bextOriginator;
    IBOutlet NSTextField *bextOriginatorRef;
    IBOutlet NSTextField *bextUMID;
    IBOutlet NSTextField *bextVersion;
    IBOutlet NSTextField *bextTimecode;
    
    IBOutlet NSPopUpButton *convertFormat;
    IBOutlet NSPopUpButton *convertSubformat;
    IBOutlet NSTableView *convertTable;
    IBOutlet NSWindow *convertSheet;
    IBOutlet NSProgressIndicator *convertProgress;
    IBOutlet NSButton *convertKeepBEXT;
    
    IBOutlet NSButton *playButton;
    IBOutlet NSPopUpButton *leftChannel;
    IBOutlet NSPopUpButton *rightChannel;
    IBOutlet NSSlider *playSlider;
    IBOutlet NSTextField *playPos;
}

- (IBAction) play : (id) sender;
- (IBAction) bextUpdateTimecode: (id) sender;
- (IBAction) bextUpdateTimecode_fps: (id) sender;
- (IBAction) convertFormatSelected: (id) sender;
- (IBAction) convert: (id) sender;
- (IBAction) convertCancel: (id) sender;
- (IBAction) playSliderMoved: (id) sender;
- (IBAction) setString: (id) sender;
- (IBAction) setOutputMapping: (id) sender;


@end
