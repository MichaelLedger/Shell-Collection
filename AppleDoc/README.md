# AppIeDoc

## 背景介绍
生成文档有三种方式： 

[docxygen](https://www.doxygen.nl/index.html)

[headerdoc](http://developer.apple.com/opensource/tools/headerdoc.html)

[appledoc](http://gentlebytes.com/appledoc/)

### docxygen
感觉是这3个工具中支持语言最多的，可以配置的地方也比较多。
我大概看了一下文档，觉得还是比较复杂，而且默认生成的风格与苹果的风格不一致。
就去看后面2个工具的介绍了。另外，它虽然是开源软件，但是没有将源码放到github上让我感觉这个工具的开发活跃度是不是不够。

### headerdoc
headerdoc 是xcode 自带的文档生成工具。
在安装完xcode后，就可以用命令行：`headdoc2html + 源文件名` 来生成对应的文档。
我个人试用了一下，还是比较方便的，不过headerdoc的注释生成规则比较特别，只生成以 /! / 的格式的注释。
还有一个缺点是每个类文件对应一个注释文件，没有汇总的文件，这点感觉有点不爽。

### appledoc
appledoc是在stackoverflow上被大家推荐的一个注释工具。有几个原因造成我比较喜欢它：
它默认生成的文档风格和苹果的官方文档是一致的，而doxygen需要另外配置。 
appledoc就是用objective-c生成的，必要的时候调试和改动也比较方便。 
可以生成docset，并且集成到xcode中。这一点是很赞的，相当于在源码中按住option再单击就可以调出相应方法的帮助。 
appledoc源码在github上，而doxygen在svn上。我个人比较偏激地认为比较活跃的开源项目都应该在github上。 
相对于headerdoc，它没有特殊的注释要求，可以用/* / 的格式，也可以兼容/! /的格式的注释，并且生成的注释有汇总页面。

## 使用步骤
### 安装
- 安装方式一
```
% git clone git://github.com/tomaz/appledoc.git
% cd ./appledoc
% sudo sh install-appledoc.sh
```

- 安装方式二
`% brew install appledoc`

查看是否安装成功
`% appledoc —version`

### 使用
将脚本拷贝到项目的根目录下，运行脚本即可，有两个脚本，根据个人喜好选择使用即可：
其中 `appledoc.sh` 需要手动修改内部参数，而 `appledoc-generator.sh` 可以传参
```
% ./appledoc.sh
```
or
```
% sh appledoc-generator.sh -t <targetName> -p .
```

### Docset
如果没有设置 `--no-create-docset`，默认会生成Docset并存放到目录，这样Xcode也可以读取帮助文件：

`~/Library/Developer/Shared/Documentation/DocSets`

### 注释格式
```
1. /*!  this a test . */
2. /**  this a comment. */
3. /// this is a long comment. */
```

### 注释常用标签
```
/**
@brief : 使用它来写一段你正在文档化的method, PRoperty, class, file, struct, 或enum的短描述信息。
@param:通过它你可以描述一个 method 或 function的参数信息。你可以使用多个这种标签。
@return: 用它来制定一个 method 或 function的返回值。
@discusstion: 用它来写一段详尽的描述。如果需要你可以添加换行。
@see: 用它来指明其他相关的 method 或 function。你可以使用多个这种标签。
@sa:同上
@code ： 使用这个标签，你可以在文档当中嵌入代码段。当在Help Inspector当中查看文档时，代码通过在一个特别的盒子中用一种不同的字体来展示。始终记住在写的代码结尾处使用@endcode标签。
@remark : 在写文档时，用它来强调任何关于代码的特殊之处。
@warning : 警告内容
@bug : bug内容
*/
```

### 文件常用标签
```
让我介绍一些当你在记录一个文件时会用到的新标签：

@file: 使用这个标签来指出你正在记录一个文件（header 文件或不是）。如果你将使用Doxygen来输出文档，那么你最好在这个标签后面紧接着写上文件名字。它是一个top level 标签。

@header: 跟上面的类似，但是是在 HeaderDoc中使用。当你不使用 Doxygen时，不要使用上面的标签。

@author：用它来写下这个文件的创建者信息

@copyright: 添加版权信息

@version: 用它来写下这个文件的当前版本。如果在工程生命周期中版本信息有影响时这会很重要。

再一次的，我只给出最常用的标签。自己查看说明文档了解更多标签信息。

@class: 用它来指定一个class的注释文档块的开头。它是一个top level标签，在它后面应该给出class名字。

@interface: 同上

@protocol: 同上两个一样，只是针对protocols

@superclass: 当前class的superclass

@classdesign: 用这个标签来指出你为当前class使用的任何特殊设计模式（例如，你可以提到这个class是不是单例模式或者类似其它的模式）。

@coclass: 与当前class合作的另外一个class的名字。

@helps: 当前class帮助的class的名字。

@helper: 帮助当前class的class名字。

使用HeaderDoc生成文档
```

### 注释示例
```
//
//  AppDelegate.h
//  TEST
//
//  Created by Gavin Xiang on 2020/6/30.
//  Copyright © 2020 Gavin Xiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

/**
@brief Tells the delegate that the launch process has begun but that state restoration has not yet occurred.
@param application  The singleton app object.
@param launchOptions A dictionary indicating the reason the app was launched (if any). The contents of this dictionary may be empty in situations where the user launched the app directly. For information about the possible keys in this dictionary and how to handle them, see Launch Options Keys.
@see App Programming Guide for iOS, application:didFinishLaunchingWithOptions:, Local and Remote Notification Programming Guide
@discussion Use this method (and the corresponding application:didFinishLaunchingWithOptions: method) to initialize your app and prepare it to run. This method is called after your app has been launched and its main storyboard or nib file has been loaded, but before your app’s state has been restored. At the time this method is called, your app is in the inactive state.

If your app was launched by the system for a specific reason, the launchOptions dictionary contains data indicating the reason for the launch. For some launch reasons, the system may call additional methods of your app delegate. For example, if your app was launched to open a URL, the system calls the application:openURL:options: method after your app finishes initializing itself. The presence of the launch keys gives you the opportunity to plan for that behavior. In the case of a URL to open, you might want to prevent state restoration if the URL represents a document that the user wanted to open.

When asked to open a URL, the return result from this method is combined with the return result from the application:didFinishLaunchingWithOptions: method to determine if a URL should be handled. If either method returns NO, the system does not call the application:openURL:options: method. If you do not implement one of the methods, only the return value of the implemented method is considered.

In some cases, the user launches your app with a Home screen quick action. To ensure you handle this launch case correctly, read the discussion in the application:performActionForShortcutItem:completionHandler: method.
@warning If your app relies on the state restoration machinery to restore its view controllers, always show your app’s window from this method. Do not show the window in your app’s application:didFinishLaunchingWithOptions: method. Calling the window’s makeKeyAndVisible method does not make the window visible right away anyway. UIKit waits until your app’s application:didFinishLaunchingWithOptions: method finishes before making the window visible on the screen.
@bug None
@return NO if the app cannot handle the URL resource or continue a user activity, or if the app should not perform the application:performActionForShortcutItem:completionHandler: method because you’re handling the invocation of a Home screen quick action in this method; otherwise return YES. The return value is ignored if the app is launched as a result of a remote notification.
*/
- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey,id> *)launchOptions;

/**
@brief Tells the delegate that the launch process is almost done and the app is almost ready to run.
@param application  The singleton app object.
@param launchOptions A dictionary indicating the reason the app was launched (if any). The contents of this dictionary may be empty in situations where the user launched the app directly. For information about the possible keys in this dictionary and how to handle them, see Launch Options Keys.
@see application:willFinishLaunchingWithOptions:, applicationDidBecomeActive:, applicationDidEnterBackground:
@discussion Use this method (and the corresponding application:willFinishLaunchingWithOptions: method) to complete your app’s initialization and make any final tweaks. This method is called after state restoration has occurred but before your app’s window and other UI have been presented. At some point after this method returns, the system calls another of your app delegate’s methods to move the app to the active (foreground) state or the background state.

This method represents your last chance to process any keys in the launchOptions dictionary. If you did not evaluate the keys in your application:willFinishLaunchingWithOptions: method, you should look at them in this method and provide an appropriate response.

Objects that are not the app delegate can access the same launchOptions dictionary values by observing the notification named UIApplicationDidFinishLaunchingNotification and accessing the notification’s userInfo dictionary. That notification is sent shortly after this method returns.
 
The return result from this method is combined with the return result from the application:willFinishLaunchingWithOptions: method to determine if a URL should be handled. If either method returns NO, the URL is not handled. If you do not implement one of the methods, only the return value of the implemented method is considered.
@warning For app initialization, it is highly recommended that you use this method and the application:willFinishLaunchingWithOptions: method and do not use the applicationDidFinishLaunching: method, which is intended only for apps that run on older versions of iOS.
@bug None
@return NO if the app cannot handle the URL resource or continue a user activity, otherwise return YES. The return value is ignored if the app is launched as a result of a remote notification.
*/
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;

@end


```

