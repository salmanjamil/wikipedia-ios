#import "WMFRelatedSectionController.h"

// Networking & Model
#import "WMFRelatedSearchFetcher.h"
#import "MWKTitle.h"
#import "WMFRelatedSearchResults.h"
#import "MWKSearchResult.h"
#import "MWKSavedPageList.h"

// Controllers
#import "WMFRelatedTitleListDataSource.h"

// Frameworks
#import "Wikipedia-Swift.h"

// View
#import "WMFArticlePreviewTableViewCell.h"
#import "WMFArticlePlaceholderTableViewCell.h"
#import "UIView+WMFDefaultNib.h"

// Style
#import "UIFont+WMFStyle.h"
#import "NSString+FormattedAttributedString.h"

static NSString* const WMFRelatedSectionIdentifierPrefix = @"WMFRelatedSectionIdentifier";
static NSUInteger const WMFRelatedSectionMaxResults      = 3;

@interface WMFRelatedSectionController ()

@property (nonatomic, strong, readwrite) MWKTitle* title;
@property (nonatomic, strong, readwrite) WMFRelatedSearchFetcher* relatedSearchFetcher;
@property (nonatomic, strong) MWKSavedPageList* savedPageList;

@property (nonatomic, strong) WMFRelatedTitleListDataSource* relatedTitleDataSource;

@end

@implementation WMFRelatedSectionController
@synthesize relatedTitleDataSource = _relatedTitleDataSource;

@synthesize delegate = _delegate;

- (instancetype)initWithArticleTitle:(MWKTitle*)title
                       savedPageList:(MWKSavedPageList*)savedPageList {
    return [self initWithArticleTitle:title
                        savedPageList:savedPageList
                 relatedSearchFetcher:[[WMFRelatedSearchFetcher alloc] init]];
}

- (instancetype)initWithArticleTitle:(MWKTitle*)title
                       savedPageList:(MWKSavedPageList*)savedPageList
                relatedSearchFetcher:(WMFRelatedSearchFetcher*)relatedSearchFetcher {
    NSParameterAssert(title);
    NSParameterAssert(savedPageList);
    NSParameterAssert(relatedSearchFetcher);
    self = [super init];
    if (self) {
        self.relatedSearchFetcher = relatedSearchFetcher;
        self.title                = title;
        self.savedPageList        = savedPageList;
        [self fetchRelatedArticles];
    }
    return self;
}

- (id)sectionIdentifier {
    return [WMFRelatedSectionIdentifierPrefix stringByAppendingString:self.title.text];
}

- (UIImage*)headerIcon {
    return [UIImage imageNamed:@"home-recent"];
}

- (NSAttributedString*)headerText {
    return
        [MWLocalizedString(@"home-continue-related-heading", nil) attributedStringWithAttributes:nil
                                                                             substitutionStrings:@[self.title.text]
                                                                          substitutionAttributes:@[@{NSLinkAttributeName: self.title.desktopURL}]
        ];
}

- (NSString*)footerText {
    return
        [MWLocalizedString(@"home-more-like-footer", nil) stringByReplacingOccurrencesOfString:@"$1"
                                                                                    withString:self.title.text];
}

- (NSArray*)items {
    if (self.relatedTitleDataSource.relatedSearchResults.results) {
        return [self.relatedTitleDataSource.relatedSearchResults.results
                wmf_safeSubarrayWithRange:NSMakeRange(0, WMFRelatedSectionMaxResults)];
    } else {
        return @[@1, @2, @3];
    }
}

- (MWKTitle*)titleForItemAtIndex:(NSUInteger)index {
    MWKSearchResult* result = self.items[index];
    MWKSite* site           = self.title.site;
    MWKTitle* title         = [site titleWithString:result.displayTitle];
    return title;
}

- (void)registerCellsInTableView:(UITableView*)tableView {
    [tableView registerNib:[WMFArticlePreviewTableViewCell wmf_classNib] forCellReuseIdentifier:[WMFArticlePreviewTableViewCell identifier]];
    [tableView registerNib:[WMFArticlePlaceholderTableViewCell wmf_classNib] forCellReuseIdentifier:[WMFArticlePlaceholderTableViewCell identifier]];
}

- (UITableViewCell*)dequeueCellForTableView:(UITableView*)tableView atIndexPath:(NSIndexPath*)indexPath {
    if (self.relatedTitleDataSource.relatedSearchResults.results) {
        return [WMFArticlePreviewTableViewCell cellForTableView:tableView];
    } else {
        return [WMFArticlePlaceholderTableViewCell cellForTableView:tableView];
    }
}

- (void)configureCell:(UITableViewCell*)cell withObject:(id)object inTableView:(UITableView*)tableView atIndexPath:(NSIndexPath*)indexPath {
    if ([cell isKindOfClass:[WMFArticlePreviewTableViewCell class]]) {
        WMFArticlePreviewTableViewCell* previewCell = (id)cell;
        MWKSearchResult* result                     = object;
        previewCell.titleText       = result.displayTitle;
        previewCell.descriptionText = result.wikidataDescription;
        previewCell.snippetText     = result.extract;
        [previewCell setImageURL:result.thumbnailURL];
        [previewCell setSaveableTitle:[self titleForItemAtIndex:indexPath.row] savedPageList:self.savedPageList];
    }
}

- (WMFRelatedTitleListDataSource*)relatedTitleDataSource {
    if (!_relatedTitleDataSource) {
        /*
           HAX: Need to use the "more" data source to fetch data and keep it around since morelike: searches for the same
           title don't have the same results in order. might need to look into continuation soon
         */
        _relatedTitleDataSource = [[WMFRelatedTitleListDataSource alloc]
                                   initWithTitle:self.title
                                       dataStore:self.savedPageList.dataStore
                                   savedPageList:self.savedPageList
                                     resultLimit:WMFMaxRelatedSearchResultLimit
                                         fetcher:self.relatedSearchFetcher];
    }
    return _relatedTitleDataSource;
}

- (SSArrayDataSource<WMFTitleListDataSource>*)extendedListDataSource {
    if (!self.relatedSearchFetcher.isFetching && !self.relatedTitleDataSource.relatedSearchResults) {
        [self.relatedTitleDataSource fetch];
    }
    return self.relatedTitleDataSource;
}

#pragma mark - Section Updates

- (void)updateSectionWithResults:(WMFRelatedSearchResults*)results {
}

- (void)updateSectionWithSearchError:(NSError*)error {
}

#pragma mark - Fetch

- (void)fetchRelatedArticles {
    if (self.relatedSearchFetcher.isFetching) {
        return;
    }
    @weakify(self);
    [self.relatedTitleDataSource fetch]
    .then(^(WMFRelatedSearchResults* results){
        @strongify(self);
        [self.delegate controller:self didSetItems:self.items];
    })
    .catch(^(NSError* error){
        @strongify(self);
        [self updateSectionWithSearchError:error];
    });
}

@end
