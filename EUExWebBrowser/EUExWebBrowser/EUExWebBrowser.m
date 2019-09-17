/**
 *
 *	@file   	: EUExWebBrowser.m  in EUExWebBrowser
 *
 *	@author 	: CeriNo
 * 
 *	@date   	: 2017/4/5
 *
 *	@copyright 	: 2017 The AppCan Open Source Project.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


#import "EUExWebBrowser.h"
#import <WebKit/WebKit.h>

@interface EUExWebBrowser() <WKUIDelegate, WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webview;
@property (nonatomic, strong) NSString *userAgent;
@end

@implementation EUExWebBrowser


- (instancetype)initWithWebViewEngine:(id<AppCanWebViewEngineObject>)engine{
    if (self = [super initWithWebViewEngine:engine]) {
        
    }
    return self;
}

- (void)clean{
    if (self.webview) {
        self.webview.UIDelegate = nil;
        self.webview.navigationDelegate = nil;
        [self.webview stopLoading];
        [self.webview removeFromSuperview];
        self.webview = nil;
    }
}



- (void)dealloc{
    [self clean];
}


#pragma mark - API

- (void)init:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSDictionary *info) = inArguments;
    self.userAgent = stringArg(info[@"userAgent"]);
    
}

- (void)open:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSDictionary *info) = inArguments;
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    NSNumber *x = numberArg(info[@"x"]) ?: @0;
    NSNumber *y = numberArg(info[@"y"]) ?: @0;
    NSNumber *width = numberArg(info[@"width"]) ?: @(screenSize.width);
    NSNumber *height = numberArg(info[@"height"]) ?: @(screenSize.height);
    CGRect frame = CGRectMake(x.floatValue, y.floatValue, width.floatValue, height.floatValue);
    [self clean];
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc]init];
    config.allowsInlineMediaPlayback = YES;
    self.webview = [[WKWebView alloc]initWithFrame:frame configuration:config];
    self.webview.navigationDelegate = self;
    self.webview.UIDelegate = self;
    
    if (ACSystemVersion() >= 9) {
        self.webview.customUserAgent = self.userAgent;
    }
    NSString *urlString = stringArg(info[@"url"]);
    // 加载页面
    [self loadAllUrl:urlString];
    // 将WKWebView添加到界面中
    [[self.webViewEngine webView] addSubview:self.webview];
}


- (void)close:(NSMutableArray *)inArguments{
    [self clean];
}

- (void)goBack:(NSMutableArray *)inArguments{
    [self.webview goBack];
}

- (void)goForward:(NSMutableArray *)inArguments{
    [self.webview goForward];
}

- (UEX_BOOL)canGoBack:(NSMutableArray *)inArguments{
    return self.webview.canGoBack ? UEX_TRUE : UEX_FALSE;
}

- (UEX_BOOL)canGoForward:(NSMutableArray *)inArguments{
    return self.webview.canGoForward ? UEX_TRUE : UEX_FALSE;
}

- (NSString *)getTitle:(NSMutableArray *)inArguments{
    return self.webview.title;
}


- (void)reload:(NSMutableArray *)inArguments{
    [self.webview reload];
}

/**
 加载本地或在线页面（处理AppCan引擎逻辑下的多种情况）

 @param urlString 需要加载的url
 */
- (void)loadAllUrl:(NSString *)urlString {
    NSURL *url = nil;
    if ([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"https://"]) {
        // 在线资源
        url = [NSURL URLWithString:urlString];
        if (url) {
            [self.webview loadRequest:[NSURLRequest requestWithURL:url]];
        }
    } else {
        // 本地资源
        NSString *documentsRootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)lastObject];
        NSString *mainBundleRootPath = [[NSBundle mainBundle] resourcePath];
        ACLogDebug(@"AppCan===>uexWebBrowser===>urlString===>%@", urlString);
        // NSString *realUrlString = [urlString hasPrefix:@"file://"]?[urlString substringFromIndex:7]:urlString;
        // url = [NSURL fileURLWithPath:realUrlString];
        // note：这里之所以没有用fileUrlWithPath而是手动拼接file://再使用urlWithString方法，是为了防止将url中的特殊字符自动转义，从而导致?后面的参数失效甚至无法打开网页。
        NSString *realUrlString = [urlString hasPrefix:@"file://"]?urlString:[NSString stringWithFormat:@"file://%@", urlString];
        url = [NSURL URLWithString:realUrlString];
        // allowingReadAccessToURL这个参数是WKWebView为了读取本地资源的时候设置允许读取的资源范围
        NSString *allowingReadAccessToURL = nil;
        if (url) {
            if ([realUrlString containsString:mainBundleRootPath]) {
                // 这种情况下，加载的页面是在app内的mainBundle的资源
                allowingReadAccessToURL = mainBundleRootPath;
            } else if ([realUrlString containsString:documentsRootPath]) {
                // 这种情况下，加载的页面是已经拷贝到沙箱目录中了
                allowingReadAccessToURL = documentsRootPath;
            } else {
                // 其他情况，目前来看是不存在的
                allowingReadAccessToURL = realUrlString;
            }
            ACLogDebug(@"AppCan===>uexWebBrowser===>allowingReadAccessToURL===>%@", allowingReadAccessToURL);
            [self.webview loadFileURL:url allowingReadAccessToURL:[NSURL fileURLWithPath:allowingReadAccessToURL]];
        }else{
            ACLogError(@"AppCan===>uexWebBrowser===>url error, loadFileURL cancelled!");
        }
    }
}

- (void)loadUrl:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *urlString) = inArguments;
    if (!urlString || ![urlString isKindOfClass:[NSString class]]) {
        return;
    }
    // 加载页面
    [self loadAllUrl:urlString];
}

- (void)evaluateJavascript:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *js) = inArguments;
    static NSString *const kJSPrefix = @"javascript:";
    
    if ([js hasPrefix:kJSPrefix]) {
        js = [js substringFromIndex:kJSPrefix.length];
    }
    [self.webview evaluateJavaScript:js completionHandler:nil];
}

#pragma mark - WKUIDelegate
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }])];
    [[self.webViewEngine viewController] presentViewController:alertController animated:YES completion:nil];
    
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler{
    //    DLOG(@"msg = %@ frmae = %@",message,frame);
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(NO);
    }])];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }])];
    [[self.webViewEngine viewController] presentViewController:alertController animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:prompt message:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = defaultText;
    }];
    [alertController addAction:([UIAlertAction actionWithTitle:@"完成" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(alertController.textFields[0].text?:@"");
    }])];
    [[self.webViewEngine viewController] presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - WKNavigationDelegate
// 页面开始加载时调用
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {

}
// 页面加载失败时调用
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    ACLogError(@"AppCan===>uexWebBrowser===>%@",error);
}
// 当内容开始返回时调用
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
//    ACLogDebug(@"%@",webView);
}
// 页面加载完成之后调用
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
//    ACLogDebug(@"%@",webView);
}
//提交发生错误时调用
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    ACLogError(@"AppCan===>uexWebBrowser===>%@",error);
}

@end
