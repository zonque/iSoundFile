/* SoundFile */

#import <Cocoa/Cocoa.h>

@interface SoundFile : NSDocument
{
    SNDFILE *sndfile;
    SF_INFO  sfinfo;
    BOOL read_only, modified;
    BOOL is_playing;
    const char *fname;
    AudioUnit au_unit;

    IBOutlet NSTextField *string_artist;
    IBOutlet NSTextField *string_comment;
    IBOutlet NSTextField *string_copyright;
    IBOutlet NSTextField *string_date;
    IBOutlet NSTextField *string_software;
    IBOutlet NSTextField *string_title;

    IBOutlet NSTextField *label_format;
    IBOutlet NSTextField *label_samplerate;
    IBOutlet NSTextField *label_bitdepth;
    IBOutlet NSTextField *label_channels;
    IBOutlet NSTextField *label_frames;
    IBOutlet NSTextField *label_length;
    
    IBOutlet NSButton *play_button;
    IBOutlet NSPopUpButton *left_channel;
    IBOutlet NSPopUpButton *right_channel;
    IBOutlet NSSlider *play_slider;
    IBOutlet NSTextField *play_pos;

}

@end
