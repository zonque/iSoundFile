/* SoundFile */

#import <Cocoa/Cocoa.h>

@interface SoundFile : NSDocument
{
    SNDFILE *sndfile;
    SF_INFO  sfinfo;
    SF_BROADCAST_INFO bext;
    BOOL read_only, modified;
    BOOL is_playing;
    const char *fname;
    NSTimer *timer;
    AudioRenderer *audioRenderer;
    struct stat file_stat;

    IBOutlet NSTextField *string_artist;
    IBOutlet NSTextField *string_comment;
    IBOutlet NSTextField *string_copyright;
    IBOutlet NSTextField *string_date;
    IBOutlet NSTextField *string_software;
    IBOutlet NSTextField *string_title;

    IBOutlet NSTextField *label_format;
    IBOutlet NSTextField *label_samplerate;
    IBOutlet NSTextField *label_bytes_per_sample;
    IBOutlet NSTextField *label_channels;
    IBOutlet NSTextField *label_frames;
    IBOutlet NSTextField *label_length;
    IBOutlet NSTextField *label_filesize;
    IBOutlet NSTextField *label_bytes_per_second;
    IBOutlet NSTextField *label_sample_format;
    IBOutlet NSTextField *label_sections;

    IBOutlet NSTextField *bext_coding_history;
    IBOutlet NSTextField *bext_description;
    IBOutlet NSTextField *bext_origination_date;
    IBOutlet NSTextField *bext_origination_time;
    IBOutlet NSTextField *bext_originator;
    IBOutlet NSTextField *bext_originator_ref;
    IBOutlet NSTextField *bext_UMID;
    IBOutlet NSTextField *bext_version;
    IBOutlet NSTextField *bext_timecode;
    IBOutlet NSPopUpButton *bext_timecode_fps;
    
    IBOutlet NSButton *play_button;
    IBOutlet NSPopUpButton *left_channel;
    IBOutlet NSPopUpButton *right_channel;
    IBOutlet NSSlider *play_slider;
    IBOutlet NSTextField *play_pos;
}

- (IBAction) play : (id) sender;
- (IBAction) bext_update_timecode: (id) sender;
- (IBAction) bext_update_timecode_fps: (id) sender;

@end
