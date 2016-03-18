//
//  DBAttachmentAlertController.m
//  DBAttachmentPickerController
//
//  Created by Denis Bogatyrev on 14.03.16.
//
//  The MIT License (MIT)
//  Copyright (c) 2016 Denis Bogatyrev.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

@import Photos;
#import "DBAttachmentAlertController.h"
#import "DBThumbnailPhotoCell.h"
#import "NSIndexSet+DB.h"

static const CGSize kDefaultThumbnailSize = {100.f, 100.f};
static const CGFloat kDefaultItemOffset = 10.f;
static const CGFloat kDefaultInteritemSpacing = 4.f;
static NSString *const kPhotoCellIdentifier = @"DBThumbnailPhotoCellID";

@interface DBAttachmentAlertController () <UICollectionViewDataSource, UICollectionViewDelegate, PHPhotoLibraryChangeObserver>

@property (strong, nonatomic) UICollectionView *collectionView;
@property (strong, nonatomic) NSString *attachActionText;

@property (strong, nonatomic) PHFetchResult *assetsFetchResults;
@property (strong, nonatomic) PHCachingImageManager *imageManager;

@property (assign, nonatomic) PHAssetMediaType assetMediaType;

@end

@implementation DBAttachmentAlertController

#pragma mark - Class methods

+ (_Nonnull instancetype)attachmentAlertControllerWithMediaType:(PHAssetMediaType) assetMediaType
                                                  attachHandler:(nullable AlertAttachAssetsHandler)attachHandler
                                               allAlbumsHandler:(nullable AlertActionHandler)allAlbumsHandler
                                             takePictureHandler:(nullable AlertActionHandler)takePictureHandler
                                               otherAppsHandler:(nullable AlertActionHandler)otherAppsHandler
                                                  cancelHandler:(nullable AlertActionHandler)cancelHandler
{
    DBAttachmentAlertController *controller = [DBAttachmentAlertController alertControllerWithTitle:@"\n\n\n\n\n" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    controller.assetMediaType = assetMediaType;
    
    __weak DBAttachmentAlertController *weakController = controller;
    UIAlertAction *attachAction = [UIAlertAction actionWithTitle:@"All albums" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if ([weakController.collectionView indexPathsForSelectedItems].count) {
            if (attachHandler) {
                attachHandler([weakController getSelectedAssetArray]);
            }
        } else if (allAlbumsHandler) {
            allAlbumsHandler(action);
        }
    }];
    [controller addAction:attachAction];
    controller.attachActionText = attachAction.title;
    
    NSString *buttonTitle;
    switch (controller.assetMediaType) {
        case PHAssetMediaTypeVideo:
            buttonTitle = @"Take a video";
            break;
        default:
            buttonTitle = @"Take a picture";
            break;
    }
    UIAlertAction *cameraAction = [UIAlertAction actionWithTitle:buttonTitle style:UIAlertActionStyleDefault handler:takePictureHandler];
    [controller addAction:cameraAction];
    
    if (controller.assetMediaType == PHAssetMediaTypeImage) {
        UIAlertAction *otherAppsAction = [UIAlertAction actionWithTitle:@"Other apps" style:UIAlertActionStyleDefault handler:otherAppsHandler];
        [controller addAction:otherAppsAction];
    }
    
    UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:cancelHandler];
    [controller addAction:actionCancel];
    
    return controller;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc]init];
    [flowLayout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
    flowLayout.sectionInset = UIEdgeInsetsMake(.0f, kDefaultItemOffset, .0f, kDefaultItemOffset);
    flowLayout.minimumInteritemSpacing = kDefaultInteritemSpacing;
    flowLayout.itemSize = kDefaultThumbnailSize;
    
    CGRect collectionRect = CGRectMake(.0f, .0f, self.view.bounds.size.width, kDefaultThumbnailSize.height + kDefaultItemOffset *2);
    self.collectionView = [[UICollectionView alloc] initWithFrame:collectionRect collectionViewLayout:flowLayout];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.allowsMultipleSelection = YES;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.tintColor = [[[UIApplication sharedApplication] delegate] window].tintColor;
    
    [self.collectionView registerNib:[UINib nibWithNibName:NSStringFromClass([DBThumbnailPhotoCell class]) bundle:nil] forCellWithReuseIdentifier:kPhotoCellIdentifier];
    
    [self.view addSubview:self.collectionView];
    
    self.imageManager = [[PHCachingImageManager alloc] init];
    [self.imageManager stopCachingImagesForAllAssets];
    
    PHFetchOptions *allPhotosOptions = [PHFetchOptions new];
    allPhotosOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    allPhotosOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", self.assetMediaType];
    
    self.assetsFetchResults = [PHAsset fetchAssetsWithMediaType:self.assetMediaType options:allPhotosOptions];
    
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
}

- (void)dealloc {
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

#pragma mark Helpers

- (NSArray *)getSelectedAssetArray {
    NSArray *selectedItems = [self.collectionView indexPathsForSelectedItems];
    NSMutableArray *assetArray = [NSMutableArray arrayWithCapacity:selectedItems.count];
    for (NSIndexPath *indexPath in selectedItems) {
        PHAsset *asset = self.assetsFetchResults[indexPath.item];
        [assetArray addObject:asset];
    }
    return [assetArray copy];
}

#pragma mark - Accessors

- (void)setAttachActionText:(NSString *)attachActionText {
    if (![_attachActionText isEqualToString:attachActionText]) {
        UILabel *attachLabel = [self attachActionLabelForView:self.view];
        attachLabel.text = attachActionText;
        
        _attachActionText = attachActionText;
    }
}

#pragma mark Helpers

- (UILabel *)attachActionLabelForView:(UIView *)baseView {
    UILabel *label = nil;
    if ([baseView isKindOfClass:[UILabel class]] && [((UILabel *)baseView).text isEqualToString:self.attachActionText]) {
        label = (UILabel *)baseView;
    } else if (baseView.subviews.count > 0) {
        for (UIView *subview in baseView.subviews) {
            label = [self attachActionLabelForView:subview];
            if (label) {
                break;
            }
        }
    }
    return label;
}

#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    dispatch_async(dispatch_get_main_queue(), ^{
        PHFetchResultChangeDetails *collectionChanges = [changeInstance changeDetailsForFetchResult:self.assetsFetchResults];
        
        if (collectionChanges) {
            self.assetsFetchResults = [collectionChanges fetchResultAfterChanges];
            
            if (![collectionChanges hasIncrementalChanges] || [collectionChanges hasMoves]) {
                [self.collectionView reloadData];
            } else {
                [self.collectionView performBatchUpdates:^{
                    NSIndexSet *removedIndexes = [collectionChanges removedIndexes];
                    if ([removedIndexes count]) {
                        [self.collectionView deleteItemsAtIndexPaths:[removedIndexes indexPathsFromIndexesWithSection:0]];
                    }
                    
                    NSIndexSet *insertedIndexes = [collectionChanges insertedIndexes];
                    if ([insertedIndexes count]) {
                        [self.collectionView insertItemsAtIndexPaths:[insertedIndexes indexPathsFromIndexesWithSection:0]];
                    }
                    
                    NSIndexSet *changedIndexes = [collectionChanges changedIndexes];
                    if ([changedIndexes count]) {
                        [self.collectionView reloadItemsAtIndexPaths:[changedIndexes indexPathsFromIndexesWithSection:0]];
                    }
                } completion:nil];
            }
            [self.imageManager stopCachingImagesForAllAssets];
        }
    });
}

#pragma mark - UICollectionView DataSource && Delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.assetsFetchResults.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    DBThumbnailPhotoCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kPhotoCellIdentifier forIndexPath:indexPath];
    if (cell == nil) {
        cell = [DBThumbnailPhotoCell thumbnailImageCell];
    }
    [self configurePhotoCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configurePhotoCell:(DBThumbnailPhotoCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    PHAsset *asset = self.assetsFetchResults[indexPath.item];
    
    cell.tintColor = self.collectionView.tintColor;
    cell.identifier = asset.localIdentifier;
    cell.needsDisplayEmptySelectedIndicator = YES;
    
    CGFloat scale = [UIScreen mainScreen].scale;
    CGSize scaledThumbnailSize = CGSizeMake( kDefaultThumbnailSize.width * scale, kDefaultThumbnailSize.height * scale );
    
    [self.imageManager requestImageForAsset:asset
                                 targetSize:scaledThumbnailSize
                                contentMode:PHImageContentModeAspectFill
                                    options:nil
                              resultHandler:^(UIImage *result, NSDictionary *info) {
                                  if ([cell.identifier isEqualToString:asset.localIdentifier]) {
                                      cell.imageVeiw.image = result;
                                  }
                              }];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self updateAttachPhotoCountIfNedded];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self updateAttachPhotoCountIfNedded];
}

#pragma mark Helpers

- (void)updateAttachPhotoCountIfNedded {
    NSArray *selectedItems = [self.collectionView indexPathsForSelectedItems];
    self.attachActionText = ( selectedItems.count ? [NSString stringWithFormat:@"Attach %zd files", selectedItems.count] : @"All albums" );
}

@end
