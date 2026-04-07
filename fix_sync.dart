import 'dart:io';

void main() async {
  final file = File(r'd:\sata projects\pos2\mobile-pos\lib\services\sync_service.dart');
  var content = await file.readAsString();

  content = content.replaceAll(
    "['admin_id'] = m['user_id'] ?? uid;\n          m.remove('user_id');",
    "['user_id'] = m['user_id'] ?? uid;"
  );

  content = content.replaceAll(
    "['admin_id'] = retData['user_id'] ?? uid;\n            retData.remove('user_id');\n            retData['user_id'] = retData['staff_id'];\n            retData.remove('staff_id');",
    "['user_id'] = retData['user_id'] ?? uid;\n            // staff_id stays as is"
  );
  
  content = content.replaceAll(
    "['admin_id'] = productMap['user_id'] ?? uid;\n            productMap.remove('user_id');\n            productMap['user_id'] = productMap['staff_id'];\n            productMap.remove('staff_id');",
    "['user_id'] = productMap['user_id'] ?? uid;\n            // staff_id stays as is"
  );

  content = content.replaceAll(
    "['admin_id'] = m['user_id'] ?? uid;\n            m.remove('user_id');",
    "['user_id'] = m['user_id'] ?? uid;"
  );

  content = content.replaceAll(
    "['admin_id'] = itemMap['user_id'] ?? uid;\n              itemMap.remove('user_id');",
    "['user_id'] = itemMap['user_id'] ?? uid;"
  );

  content = content.replaceAll(
    "['admin_id'] = m['user_id'];\n          m.remove('user_id');",
    "['user_id'] = m['user_id'];"
  );

  content = content.replaceAll(
    "['admin_id'] = m['user_id'] ?? uid; m.remove('user_id');",
    "['user_id'] = m['user_id'] ?? uid;"
  );

  content = content.replaceAll(
    "['admin_id'] = m['user_id'] ?? uid;\n           m.remove('user_id');",
    "['user_id'] = m['user_id'] ?? uid;"
  );
  
  content = content.replaceAll(
    "['admin_id'] = m['user_id'] ?? uid;\n          m.remove('user_id');\n          m['user_id'] = m['staff_id'];\n          m.remove('staff_id');",
    "['user_id'] = m['user_id'] ?? uid;\n          // staff_id stays as is"
  );

  content = content.replaceAll(
    "['admin_id'] = m['user_id'] ?? uid;\n          m.remove('user_id');",
    "['user_id'] = m['user_id'] ?? uid;"
  );

  content = content.replaceAll(
    "['admin_id'] = m['user_id'] ?? uid;\n            m.remove('user_id');",
    "['user_id'] = m['user_id'] ?? uid;"
  );

  content = content.replaceAll(
    "['admin_id'] = m['user_id'] ?? uid;\n          m.remove('user_id');",
    "['user_id'] = m['user_id'] ?? uid;"
  );

  content = content.replaceAll(
    "m['admin_id'] = m['user_id'] ?? uid;",
    "m['user_id'] = m['user_id'] ?? uid;"
  );
  
  content = content.replaceAll(
    "retData['admin_id'] = retData['user_id'] ?? uid;",
    "retData['user_id'] = retData['user_id'] ?? uid;"
  );

  content = content.replaceAll(
    "itemMap['admin_id'] = itemMap['user_id'] ?? uid;",
    "itemMap['user_id'] = itemMap['user_id'] ?? uid;"
  );
  
  content = content.replaceAll(
    "productMap['admin_id'] = productMap['user_id'] ?? uid;",
    "productMap['user_id'] = productMap['user_id'] ?? uid;"
  );

  content = content.replaceAll(
    "saleData['admin_id'] = saleData['user_id'] ?? uid;",
    "saleData['user_id'] = saleData['user_id'] ?? uid;"
  );
  
  content = content.replaceAll(
    "['admin_id'] = m['user_id'];",
    "['user_id'] = m['user_id'];"
  );
  
  content = content.replaceAll(
    "m.remove('user_id');",
    "// m.remove('user_id');"
  );
  
  content = content.replaceAll(
    "['user_id'] = m['staff_id'];",
    "// ['user_id'] = m['staff_id'];"
  );
  
  content = content.replaceAll(
    "m.remove('staff_id');",
    "// m.remove('staff_id');"
  );

  content = content.replaceAll(
    "saleData.remove('user_id');",
    "// saleData.remove('user_id');"
  );
  
  content = content.replaceAll(
    "saleData['user_id'] = saleData['staff_id'];",
    "// saleData['user_id'] = saleData['staff_id'];"
  );
  
  content = content.replaceAll(
    "saleData.remove('staff_id');",
    "// saleData.remove('staff_id');"
  );

  content = content.replaceAll(
    "retData.remove('user_id');",
    "// retData.remove('user_id');"
  );
  
  content = content.replaceAll(
    "retData['user_id'] = retData['staff_id'];",
    "// retData['user_id'] = retData['staff_id'];"
  );
  
  content = content.replaceAll(
    "retData.remove('staff_id');",
    "// retData.remove('staff_id');"
  );

  content = content.replaceAll(
    "productMap.remove('user_id');",
    "// productMap.remove('user_id');"
  );
  
  content = content.replaceAll(
    "productMap['user_id'] = productMap['staff_id'];",
    "// productMap['user_id'] = productMap['staff_id'];"
  );
  
  content = content.replaceAll(
    "productMap.remove('staff_id');",
    "// productMap.remove('staff_id');"
  );
  
  content = content.replaceAll(
    "itemMap.remove('user_id');",
    "// itemMap.remove('user_id');"
  );

  await file.writeAsString(content);
  print('Done applying replacements.');
}
