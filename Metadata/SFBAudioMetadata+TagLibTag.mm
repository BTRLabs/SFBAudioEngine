//
// Copyright (c) 2010 - 2021 Stephen F. Booth <me@sbooth.org>
// Part of https://github.com/sbooth/SFBAudioEngine
// MIT license
//

#import <CoreServices/CoreServices.h>

#import "SFBCFWrapper.hpp"

#import "AddAudioPropertiesToDictionary.h"
#import "NSError+SFBURLPresentation.h"
#import "SFBAudioMetadata+TagLibTag.h"
#import "SFBAudioMetadata+TagLibXiphComment.h"
#import "TagLibStringUtilities.h"

@implementation SFBAudioMetadata (TagLibTag)

- (void)addMetadataFromTagLibTag:(const TagLib::Tag *)tag
{
	NSParameterAssert(tag != nil);

	self.title = [NSString stringWithUTF8String:tag->title().toCString(true)];
	self.albumTitle = [NSString stringWithUTF8String:tag->album().toCString(true)];
	self.artist = [NSString stringWithUTF8String:tag->artist().toCString(true)];
	self.genre = [NSString stringWithUTF8String:tag->genre().toCString(true)];

	if(tag->year())
		self.releaseDate = @(tag->year()).stringValue;

	if(tag->track())
		self.trackNumber = @(tag->track());

	self.comment = [NSString stringWithUTF8String:tag->comment().toCString(true)];
}

@end

void SFB::Audio::SetTagFromMetadata(SFBAudioMetadata *metadata, TagLib::Tag *tag)
{
	NSCParameterAssert(metadata != nil);
	assert(nullptr != tag);

	tag->setTitle(TagLib::StringFromNSString(metadata.title));
	tag->setArtist(TagLib::StringFromNSString(metadata.artist));
	tag->setAlbum(TagLib::StringFromNSString(metadata.albumTitle));
	tag->setComment(TagLib::StringFromNSString(metadata.comment));
	tag->setGenre(TagLib::StringFromNSString(metadata.genre));
	tag->setYear(metadata.releaseDate ? (unsigned int)metadata.releaseDate.intValue : 0);
	tag->setTrack(metadata.trackNumber.unsignedIntValue);
}

void SFB::Audio::AttachFLACPicturesToMetadata(SFBAudioMetadata *metadata, TagLib::List<TagLib::FLAC::Picture*> pictureList)
{
    NSCParameterAssert(metadata != nil);

    for(auto iter : pictureList) {
        NSData *imageData = [NSData dataWithBytes:iter->data().data() length:iter->data().size()];

        NSString *description = nil;
        if(!iter->description().isEmpty())
            description = [NSString stringWithUTF8String:iter->description().toCString(true)];

        [metadata attachPicture:[[SFBAttachedPicture alloc] initWithImageData:imageData
                                                                     type:(SFBAttachedPictureType)iter->type()
                                                              description:description]];
    }
}

void SFB::Audio::SetAttachedPicturesAsFLACPictures(SFBAudioMetadata *metadata, TagLib::Ogg::XiphComment *tag, bool removeExisting)
{
    NSCParameterAssert(metadata != nil);
    assert(nullptr != tag);
    
    if(removeExisting)
        tag->removeAllPictures();
    for(SFBAttachedPicture *attachedPicture in metadata.attachedPictures) {
        TagLib::FLAC::Picture *picture = SFB::Audio::CreateFLACPicture(attachedPicture);
        if(picture)
            tag->addPicture(picture);
    }
}

void SFB::Audio::SetAttachedPicturesAsFLACPictures(SFBAudioMetadata *metadata, TagLib::FLAC::File *file, bool removeExisting)
{
    NSCParameterAssert(metadata != nil);
    assert(nullptr != file);
    
    if(removeExisting)
        file->removePictures();
    for(SFBAttachedPicture *attachedPicture in metadata.attachedPictures) {
        TagLib::FLAC::Picture *picture = SFB::Audio::CreateFLACPicture(attachedPicture);
        if(picture)
            file->addPicture(picture);
    }
}

TagLib::FLAC::Picture* SFB::Audio::CreateFLACPicture(SFBAttachedPicture *attachedPicture)
{
    SFB::CGImageSource imageSource(CGImageSourceCreateWithData((__bridge CFDataRef)attachedPicture.imageData, nullptr));
    if(!imageSource)
        return nil;

    TagLib::FLAC::Picture *picture = new TagLib::FLAC::Picture();
    picture->setData(TagLib::ByteVector((const char *)attachedPicture.imageData.bytes, (size_t)attachedPicture.imageData.length));
    picture->setType((TagLib::FLAC::Picture::Type)attachedPicture.pictureType);
    if(attachedPicture.pictureDescription)
        picture->setDescription(TagLib::StringFromNSString(attachedPicture.pictureDescription));

    // Convert the image's UTI into a MIME type
    NSString *mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(CGImageSourceGetType(imageSource), kUTTagClassMIMEType);
    if(mimeType)
        picture->setMimeType(TagLib::StringFromNSString(mimeType));

    // Flesh out the height, width, and depth
    NSDictionary *imagePropertiesDictionary = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nullptr);
    if(imagePropertiesDictionary) {
        NSNumber *imageWidth = imagePropertiesDictionary[(__bridge NSString *)kCGImagePropertyPixelWidth];
        NSNumber *imageHeight = imagePropertiesDictionary[(__bridge NSString *)kCGImagePropertyPixelHeight];
        NSNumber *imageDepth = imagePropertiesDictionary[(__bridge NSString *)kCGImagePropertyDepth];

        picture->setHeight(imageHeight.intValue);
        picture->setWidth(imageWidth.intValue);
        picture->setColorDepth(imageDepth.intValue);
    }
    
    return picture;
}
