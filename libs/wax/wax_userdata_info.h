//
//  wax_userdata.h
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-29.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#ifndef CocosLua_wax_userdata_h
#define CocosLua_wax_userdata_h

typedef enum {
    wax_unknown_type = 0,
    wax_instance_type,
    wax_struct_type,
} wax_userdata_type;

typedef struct _wax_userdata_info {
    wax_userdata_type type;
} wax_userdata_info;

#endif
