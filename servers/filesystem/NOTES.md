# 9p2000 Messages
```
VersionRequest:    size[4] Tversion tag[2] msize[4] version[s]
VersionResponse:   size[4] Rversion tag[2] msize[4] version[s]
AuthRequest:       size[4] Tauth tag[2] afid[4] uname[s] aname[s]
AuthResponse:      size[4] Rauth tag[2] aqid[13]
AttachRequest:     size[4] Tattach tag[2] fid[4] afid[4] uname[s] aname[s]
AttachResponse:    size[4] Rattach tag[2] qid[13]
ErrorResponse:     size[4] Rerror tag[2] ename[s]
FlushRequest:      size[4] Tflush tag[2] oldtag[2]
FlushResponse:     size[4] Rflush tag[2]
WalkRequest:       size[4] Twalk tag[2] fid[4] newfid[4] nwname[2] nwname*(wname[s])
WalkResponse:      size[4] Rwalk tag[2] nwqid[2] nwqid*(wqid[13])
OpenRequest:       size[4] Topen tag[2] fid[4] mode[1]
OpenResponse:      size[4] Ropen tag[2] qid[13] iounit[4]
CreateRequest:     size[4] Tcreate tag[2] fid[4] name[s] perm[4] mode[1]
CreateResponse:    size[4] Rcreate tag[2] qid[13] iounit[4]
ReadRequest:       size[4] Tread tag[2] fid[4] offset[8] count[4]
ReadResponse:      size[4] Rread tag[2] count[4] data[count]
WriteRequest:      size[4] Twrite tag[2] fid[4] offset[8] count[4] data[count]
WriteResponse:     size[4] Rwrite tag[2] count[4]
ClunkRequest:      size[4] Tclunk tag[2] fid[4]
ClunkResponse:     size[4] Rclunk tag[2]
RemoveRequest:     size[4] Tremove tag[2] fid[4]
RemoveResponse:    size[4] Rremove tag[2]
StatRequest:       size[4] Tstat tag[2] fid[4]
StatResponse:      size[4] Rstat tag[2] stat[n]
WriteStatRequest:  size[4] Twstat tag[2] fid[4] stat[n]
WriteStatResponse: size[4] Rwstat tag[2]
```
# 9p2000 Support Structures
```
Qid:  type[1] version[4] path[8]
Stat: size[2] type[2] dev[4] qid[13] mode[4] atime[4] mtime[4] length[8]
      name[s] uid[s] gid[s] muid[s]
```