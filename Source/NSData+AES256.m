//
//  NSMutableData+AES256.m
//  
//
//  Created by Simone Manganelli on 2012-03-19
//

#import "NSData+AES256.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>

@implementation NSData (AES256)

// modified from http://stackoverflow.com/questions/1028742/compute-a-checksum-on-the-iphone-from-nsdata
- (NSString *)md5String;
{
    void *cData = malloc([self length]);
    unsigned char resultCString[16];
    [self getBytes:cData length:[self length]];
    
    CC_MD5(cData, [self length], resultCString);
    free(cData);
    
    NSString *result = [NSString stringWithFormat:
                        @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
                        resultCString[0], resultCString[1], resultCString[2], resultCString[3], 
                        resultCString[4], resultCString[5], resultCString[6], resultCString[7],
                        resultCString[8], resultCString[9], resultCString[10], resultCString[11],
                        resultCString[12], resultCString[13], resultCString[14], resultCString[15]
                        ];
    return result;
}

@end
