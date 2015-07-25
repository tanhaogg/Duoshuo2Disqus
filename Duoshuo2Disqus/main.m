//
//  main.m
//  Duoshuo2Disqus
//
//  Created by TanHao on 15-7-25.
//  Copyright (c) 2015年 TanHao. All rights reserved.
//

#import <Foundation/Foundation.h>

#define INPUT_PATH @"/Users/tanhao/Desktop/export.json"
#define OUTPUT_PATH @"/Users/tanhao/Desktop/result.xml"

#define SAFESTR(a) (a ?: @"")

// 过滤无效的XML字符
NSString *FilterString(NSString *string)
{
    NSMutableString *cleanedString = [[NSMutableString alloc] init];
    for (NSInteger index = 0; index < string.length; index++)
    {
        unichar character = [string characterAtIndex:index];
        
        if (character == 0x9 ||
            character == 0xA ||
            character == 0xD ||
            (character >= 0x20 && character <= 0xD7FF) ||
            (character >= 0xE000 && character <= 0xFFFD))
            [cleanedString appendFormat:@"%C", character];
    }
    return cleanedString;
}

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSData *inputData = [[NSData alloc] initWithContentsOfFile:INPUT_PATH];
        NSMutableDictionary *info = [NSJSONSerialization JSONObjectWithData:inputData
                                                                    options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves
                                                                      error:NULL];
        
        // 将文章按thread_id分组
        NSMutableArray *threads = info[@"threads"];
        NSMutableArray *items = [NSMutableArray arrayWithCapacity:threads.count];
        NSMutableDictionary *threadId2Item = [NSMutableDictionary dictionaryWithCapacity:threads.count];
        for (NSDictionary *aThread in threads)
        {
            [items addObject:aThread];
            id thread_id = aThread[@"thread_id"];
            threadId2Item[thread_id] = aThread;
        }
        
        // 将评论按thread_id分组
        NSMutableArray *posts = info[@"posts"];
        NSMutableDictionary *threadId2commentList = [NSMutableDictionary dictionary];
        for (NSDictionary *aPost in posts)
        {
            id thread_id = aPost[@"thread_id"];
            NSMutableArray *postList = threadId2commentList[thread_id];
            if (!postList)
            {
                postList = [NSMutableArray array];
                threadId2commentList[thread_id] = postList;
            }
            [postList addObject:aPost];
        }
        
        NSXMLElement *channelElement = [[NSXMLElement alloc] initWithName:@"channel"];
        
        for (NSDictionary *item in items)
        {
            NSXMLElement *itemNode = [[NSXMLElement alloc] initWithName:@"item"];
            [channelElement addChild:itemNode];
            
            // 文章
            {
                [itemNode addChild:[NSXMLElement elementWithName:@"title" stringValue:FilterString(SAFESTR(item[@"title"]))]];
                [itemNode addChild:[NSXMLElement elementWithName:@"link" stringValue:FilterString(SAFESTR(item[@"url"]))]];
                [itemNode addChild:[NSXMLElement elementWithName:@"dsq:thread_identifier" stringValue:FilterString(SAFESTR(item[@"thread_key"]))]];
                [itemNode addChild:[NSXMLElement elementWithName:@"content:encoded" stringValue:@""]];
                [itemNode addChild:[NSXMLElement elementWithName:@"wp:post_date_gmt" stringValue:@""]];
                [itemNode addChild:[NSXMLElement elementWithName:@"wp:comment_status" stringValue:@"open"]];
            }
            
            id thread_id = item[@"thread_id"];
            NSArray *comments = threadId2commentList[thread_id];
            
            // 评论
            for (NSDictionary *comment in comments)
            {
                NSXMLElement *commentNode = [[NSXMLElement alloc] initWithName:@"wp:comment"];
                [itemNode addChild:commentNode];
                
                // 转换时间格式
                NSString *gmtDate = SAFESTR(comment[@"created_at"]);
                gmtDate = [gmtDate stringByReplacingOccurrencesOfString:@"T" withString:@" "];
                NSRange range = [gmtDate rangeOfString:@"+"];
                if (range.length > 0)
                {
                    gmtDate = [gmtDate substringToIndex:range.location];
                }
                
                NSXMLElement *remoteNode = [[NSXMLElement alloc] initWithName:@"dsq:remote"];
                [commentNode addChild:remoteNode];
                
                [remoteNode addChild:[NSXMLElement elementWithName:@"dsq:id" stringValue:@""]];
                [remoteNode addChild:[NSXMLElement elementWithName:@"dsq:avatar" stringValue:@""]];
                
                [commentNode addChild:[NSXMLElement elementWithName:@"wp:comment_id" stringValue:SAFESTR(comment[@"post_id"])]];
                [commentNode addChild:[NSXMLElement elementWithName:@"wp:comment_author" stringValue:FilterString(SAFESTR(comment[@"author_name"]))]];
                [commentNode addChild:[NSXMLElement elementWithName:@"wp:comment_author_email" stringValue:FilterString(SAFESTR(comment[@"author_email"]))]];
                [commentNode addChild:[NSXMLElement elementWithName:@"wp:comment_author_url" stringValue:FilterString(SAFESTR(comment[@"author_url"]))]];
                [commentNode addChild:[NSXMLElement elementWithName:@"wp:comment_author_IP" stringValue:FilterString(SAFESTR(comment[@"ip"]))]];
                [commentNode addChild:[NSXMLElement elementWithName:@"wp:comment_date_gmt" stringValue:gmtDate]];
                [commentNode addChild:[NSXMLElement elementWithName:@"wp:comment_content" stringValue:FilterString(SAFESTR(comment[@"message"]))]];
                [commentNode addChild:[NSXMLElement elementWithName:@"wp:comment_approved" stringValue:@"1"]];
                [commentNode addChild:[NSXMLElement elementWithName:@"wp:comment_parent" stringValue:SAFESTR(comment[@"parent_id"])]];
            }
        }
        
        NSXMLElement *rootElement = [[NSXMLElement alloc] initWithName:@"rss"];
        [rootElement addNamespace:[NSXMLElement namespaceWithName:@"content" stringValue:@"http://purl.org/rss/1.0/modules/content/"]];
        [rootElement addNamespace:[NSXMLElement namespaceWithName:@"dsq" stringValue:@"http://www.disqus.com/"]];
        [rootElement addNamespace:[NSXMLElement namespaceWithName:@"dc" stringValue:@"http://purl.org/dc/elements/1.1/"]];
        [rootElement addNamespace:[NSXMLElement namespaceWithName:@"wp" stringValue:@"http://wordpress.org/export/1.0/"]];
        [rootElement addChild:channelElement];
        
        NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithRootElement:rootElement];
        [xmlDoc setVersion:@"1.0"];
        [xmlDoc setCharacterEncoding:@"utf-8"];
        [[xmlDoc XMLData] writeToFile:OUTPUT_PATH atomically:YES];
    }
    return 0;
}
