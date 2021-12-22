//
//  main.m
//  rmOldArchives
//
//  Created by 大大东 on 2020/8/12.
//  Copyright © 2020 大大东. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PathItem : NSObject
@property NSString *version;
@property NSString *fullPatch;
@property NSDate *creatDate;
@end
@implementation PathItem
@end

@interface ProjectItem : NSObject
@property NSString *bundleId;
@property NSMutableArray<PathItem *> *patchArray;
- (void)clean;
@end
@implementation ProjectItem
- (instancetype)init
{
    self = [super init];
    if (self) {
        _patchArray = [NSMutableArray new];
    }
    return self;
}
- (void)clean {
    printf(" \n");
    printf("开始处理--Xcode-archives: %s \n", self.bundleId.UTF8String);
    
    [self.patchArray sortUsingComparator:^NSComparisonResult(PathItem  * obj1, PathItem  * obj2) {
        
        if ([obj1.version compare:obj2.version] != NSOrderedSame) {
            return [obj1.version compare:obj2.version];
        }
        
        return [obj1.creatDate compare:obj2.creatDate];
    }];
    
    NSString *maxVer = [self.patchArray lastObject].version;
    printf("step: maxVer %s \n", maxVer.UTF8String);
    __block NSString *curDelVer = maxVer;
    __block int       distance  = 0;
    // 最新版本全保留
    // maxVer - 5 > 0 的全部删除, <0 的只保留最新的一个
    // Reverse enum
    [self.patchArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(PathItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.version isEqualToString:maxVer]) {
            /// maxVer not del
            return;
        }
        // not maxVer save newest
        if (![obj.version isEqualToString:curDelVer]) {
            curDelVer = obj.version;
            distance++;
            if (distance <= 5) {
                printf("step: newst with ver %s \n", obj.version.UTF8String);
                return;
            }
            printf("ver is too old %s \n", obj.version.UTF8String);
        }
        if ([[NSFileManager defaultManager] removeItemAtPath:obj.fullPatch error:nil]) {
            
            printf("删除: %s  %s \n",obj.version.UTF8String ,obj.fullPatch.UTF8String);
        }
    }];
}
@end




void cleanXCodeArchives() {
    
    NSFileManager *fManager = [NSFileManager defaultManager];
    
    NSString *archivesDir =  @"~/Library/Developer/Xcode/Archives";
    
    NSArray *subDicArr = [fManager contentsOfDirectoryAtPath:archivesDir error:nil];
    if (subDicArr.count == 0) {
        return;
    }
    
    NSMutableDictionary *mdic = [[NSMutableDictionary alloc] init];
    for (NSString *subDir in subDicArr) {
        NSString *fullPath = [archivesDir stringByAppendingPathComponent:subDir];
        BOOL flag = NO;
        if (([fManager fileExistsAtPath:fullPath isDirectory:&flag] && flag) == NO) {
            continue;
        }
        NSArray *archveFilesArr = [fManager contentsOfDirectoryAtPath:fullPath error:nil];
        if (archveFilesArr.count == 0) {
            continue;
        }
        for (NSString *archveFilePath in archveFilesArr) {
            NSString *newfullPath = [fullPath stringByAppendingPathComponent:archveFilePath];
            flag = NO;
            if (([fManager fileExistsAtPath:newfullPath isDirectory:&flag] && flag) == NO) {
                continue;
            }
            NSDictionary *infoplistContent = [NSDictionary dictionaryWithContentsOfFile:[newfullPath stringByAppendingPathComponent:@"info.plist"]];
            NSString *bundleid = infoplistContent[@"ApplicationProperties"][@"CFBundleIdentifier"];
            NSString *ver = infoplistContent[@"ApplicationProperties"][@"CFBundleShortVersionString"];
            if (!bundleid && !ver && [@"xcarchive" isEqualToString:newfullPath.lastPathComponent.pathExtension]) {
                // 容错  不知怎么会出现一种错误的数据
                if ([fManager removeItemAtPath:newfullPath error:nil]) {
                    printf("删除 error dsym file: %s \n",newfullPath.UTF8String);
                }
                continue;
            }
            PathItem *item = [[PathItem alloc] init];
            item.version = ver;
            item.fullPatch = newfullPath;
            item.creatDate = [[fManager attributesOfItemAtPath:newfullPath error:nil] objectForKey:NSFileCreationDate];
            
            ProjectItem *project = mdic[bundleid];
            if (project == nil) {
                project = [[ProjectItem alloc] init];
                project.bundleId = bundleid;
                mdic[bundleid] = project;
            }
            [project.patchArray addObject:item];
        }
    }
    [mdic.allValues enumerateObjectsUsingBlock:^(ProjectItem  * obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj clean];
    }];
}








int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        NSArray<NSString *> *dirArr = @[
            @"/Users/iosci/Desktop/walkmoney_ios/fastlane/adhoc_build/BDDProject",
            @"/Users/iosci/Desktop/ShakeU/shaku_app/fastlane/adhoc_build/ShakeU",
            @"/Users/iosci/Desktop/tiny_sweet/fastlane/adhoc_build/TinySweet",
            @"/Users/iosci/Desktop/luckyStep/LuckyStep/fastlane/adhoc_build/LuckyStep",
            @"/Users/iosci/Desktop/catWeiQi/fastlane/adhoc_build/catWeiQi",
            @"/Users/iosci/Desktop/candyEliminate/frameworks/runtime-src/proj.ios_mac/fastlane/adhoc_build/xxl-mobile",
            @"/Users/iosci/Desktop/huanlewan/game-mj-src/proj.ios_mac/fastlane/adhoc_build",
            
            @"/Users/iosci/Desktop/huanlewan/game-ddz-src/proj.ios_mac/fastlane/adhoc_build/game-ddz-mobile-test",
            @"/Users/iosci/Desktop/huanlewan/game-ddz-src/proj.ios_mac/fastlane/adhoc_build/game-ddz-mobile-product",
            
            @"/Users/iosci/Desktop/game-chess-src/release/ios_gameview/fastlane/adhoc_build/chess-mobile-test",
            @"/Users/iosci/Desktop/game-chess-src/release/ios_gameview/fastlane/adhoc_build/chess-mobile-product"
        ];
        
        NSFileManager *fManager = [NSFileManager defaultManager];
        
        for (NSString *path in dirArr) {
            if (NO == [fManager fileExistsAtPath:path]) {
                printf("路径不存在: %s \n", path.UTF8String);
                continue;
            }
            printf("\n");
            printf("开始处理--%s \n", path.UTF8String);
            NSArray *subarr = [fManager contentsOfDirectoryAtPath:path error:nil];
            if (subarr.count == 0) {
                continue;
            }
            for (NSString *tmpPath in subarr) {
                NSString *fullPath = [path stringByAppendingPathComponent:tmpPath];
                BOOL isDir = NO;
                if (NO == [fManager fileExistsAtPath:fullPath isDirectory:&isDir] || isDir == NO) {
                    continue;
                }
                NSDate *creatDate = [[fManager attributesOfItemAtPath:fullPath error:nil] objectForKey:NSFileCreationDate];
                // 删除7天前的
                if (fabs([creatDate timeIntervalSinceNow]) > 3600 * 24 * 7) {
                    if ([fManager removeItemAtPath:fullPath error:nil]) {
                        printf("删除: %s \n",tmpPath.UTF8String);
                    }
                }
            }
        }
        
        // newst ver all save, history ver only save last
        cleanXCodeArchives();
        
    }
    return 0;
}

