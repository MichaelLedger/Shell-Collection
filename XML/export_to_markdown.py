#!/usr/bin/python
# -*- coding: UTF-8 -*-
 
from xml.dom.minidom import parse
import xml.dom.minidom

def export(data, file_name):
    # 避免忘记手动关闭文件导致资源泄露，用with自动关闭文件
    with open(file_name, 'w') as file:
        file.write(data)
 
def main():
    # 使用minidom解析器打开 XML 文档
    XMLFilePath = "academic.xml"
    DOMTree = xml.dom.minidom.parse(XMLFilePath)
    # print(DOMTree.toprettyxml())
    collection = DOMTree.documentElement
    #if collection.hasAttribute("shelf"):
    #   print "Root element : %s" % collection.getAttribute("shelf")
     
    # 在集合中获取所有电影
    blogs = collection.getElementsByTagName("blog")

    # 打印每部电影的详细信息
    for blog in blogs:
        print("*****Blog*****")
        # if blog.hasAttribute("markdown-content"):
        # print "markdown-content: %s" % blog.getAttribute("markdown-content")
        id = blog.getElementsByTagName('id')[0]
        print("id: %s" % id.childNodes[0].data)
        title = blog.getElementsByTagName('title')[0]
        print("title: %s" % title.childNodes[0].data)
        if blog.getElementsByTagName('markdown-content'):
            markdown_contents = blog.getElementsByTagName('markdown-content')
            markdown_content = markdown_contents[0]
            # print("markdown-content: \n%s" % markdown_content.childNodes[0].data)
            file_name = '/Users/gavinxiang/Downloads/MichaelLedger.github.io/markdowns/academic/' + 'academic' + '_' + id.childNodes[0].data + '.md'
            print('saving markdown-content to file at path:', file_name)
            if len(markdown_content.childNodes[0].data) > 0:
                print('length:', len(markdown_content.childNodes[0].data))
                export(markdown_content.childNodes[0].data, file_name)
            
            # 删除元素markdown-content属性
            # deleting all occurences of a particular
            # tag(here "markdown-content")
            for i in markdown_contents:
                x = i.parentNode
                x.removeChild( i )
                # 修改元素内容
                #i.nodeValue = ""
            
    print('==== export finished! 🍺🍺🍺 ====')

    # writing the changes in "file" object to
    # the "test.xml" file
    print(DOMTree.toxml())
    export(DOMTree.toxml(), 'academic_modified.xml')
    print('==== modify finished! 🎉🎉🎉 ====')
    
if __name__=="__main__":
    main();
            

