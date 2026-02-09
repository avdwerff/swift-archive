/* config.h - Configuration for Apple platforms (macOS, iOS, tvOS, watchOS) */

#ifndef CONFIG_H
#define CONFIG_H

/* Required libarchive build markers */
#define __LIBARCHIVE_BUILD 1
#define __LIBARCHIVE_CONFIG_H_INCLUDED 1

#include <TargetConditionals.h>

/* Version */
#define LIBARCHIVE_VERSION_STRING "3.8.4"
#define LIBARCHIVE_VERSION_NUMBER 3008004

/* Standard headers */
#define HAVE_STDINT_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_STRINGS_H 1
#define HAVE_UNISTD_H 1
#define HAVE_FCNTL_H 1
#define HAVE_ERRNO_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_PARAM_H 1
#define HAVE_DIRENT_H 1
#define HAVE_TIME_H 1
#define HAVE_LIMITS_H 1
#define HAVE_WCHAR_H 1
#define HAVE_WCTYPE_H 1
#define HAVE_LOCALE_H 1
#define HAVE_CTYPE_H 1
#define HAVE_GRP_H 1
#define HAVE_PWD_H 1
#define HAVE_SIGNAL_H 1
#define HAVE_SPAWN_H 1
#define HAVE_REGEX_H 1
#define HAVE_COPYFILE_H 1
#define HAVE_LANGINFO_H 1
#define HAVE_PATHS_H 1

/* Size of types */
#define SIZEOF_INT 4
#define SIZEOF_LONG 8

/* System already defines these - prevent redefinition warnings */
#define HAVE_DECL_SIZE_MAX 1
#define HAVE_DECL_SSIZE_MAX 1
#define HAVE_DECL_UINT32_MAX 1
#define HAVE_DECL_INT32_MAX 1
#define HAVE_DECL_INT32_MIN 1
#define HAVE_DECL_UINT64_MAX 1
#define HAVE_DECL_INT64_MAX 1
#define HAVE_DECL_INT64_MIN 1
#define HAVE_DECL_UINTMAX_MAX 1
#define HAVE_DECL_INTMAX_MAX 1
#define HAVE_DECL_INTMAX_MIN 1

/* Types */
#define HAVE_INTMAX_T 1
#define HAVE_UINTMAX_T 1
#define HAVE_INT64_T 1
#define HAVE_UINT64_T 1
#define HAVE_INT32_T 1
#define HAVE_UINT32_T 1
#define HAVE_INT16_T 1
#define HAVE_UINT16_T 1
#define HAVE_PID_T 1
#define HAVE_UID_T 1
#define HAVE_GID_T 1
#define HAVE_ID_T 1
#define HAVE_MODE_T 1
#define HAVE_OFF_T 1
#define HAVE_SIZE_T 1
#define HAVE_SSIZE_T 1

/* ================================================== */
/* COMPRESSION LIBRARIES                              */
/* ================================================== */

/* zlib - always available on Apple platforms */
#define HAVE_ZLIB_H 1
#define HAVE_LIBZ 1

/* bzip2 - available on macOS, not iOS */
#if TARGET_OS_OSX
#define HAVE_BZLIB_H 1
#define HAVE_LIBBZ2 1
#endif

/* lzma/xz - available via Compression framework or liblzma */
//#define HAVE_LZMA_H 1
//#define HAVE_LIBLZMA 1

/* zstd */
//#define HAVE_ZSTD_H 1
//#define HAVE_LIBZSTD 1
//#define HAVE_ZSTD_compressStream 1

/* lz4 */
//#define HAVE_LZ4_H 1
//#define HAVE_LIBLZ4 1
//#define HAVE_LZ4HC_H 1

/* ================================================== */
/* ENCRYPTION - CommonCrypto (AES)                    */
/* ================================================== */

/* CommonCrypto for hashing */
#define HAVE_COMMONCRYPTO_COMMONDIGEST_H 1
#define ARCHIVE_CRYPTO_MD5_COMMONCRYPTO 1
#define ARCHIVE_CRYPTO_SHA1_COMMONCRYPTO 1
#define ARCHIVE_CRYPTO_SHA256_COMMONCRYPTO 1
#define ARCHIVE_CRYPTO_SHA384_COMMONCRYPTO 1
#define ARCHIVE_CRYPTO_SHA512_COMMONCRYPTO 1

/* CommonCrypto for AES encryption (ZIP, 7z) */
#define HAVE_COMMONCRYPTO_COMMONCRYPTOR_H 1
#define HAVE_CCRYPTORCREATEWITHMODE 1
#define HAVE_CCCRYPTORRELEASE 1
#define HAVE_PBKDF2_SHA1 1

/* ================================================== */
/* FILE/DIRECTORY FUNCTIONS                           */
/* ================================================== */

#define HAVE_CHOWN 1
#define HAVE_FCHDIR 1
#define HAVE_FCHMOD 1
#define HAVE_FCHOWN 1
#define HAVE_FCNTL 1
#define HAVE_FORK 1
#define HAVE_FSTAT 1
#define HAVE_FSTATAT 1
#define HAVE_FTRUNCATE 1
#define HAVE_FUTIMES 1
#define HAVE_GETCWD 1
#define HAVE_LINK 1
#define HAVE_LSTAT 1
#define HAVE_MKDIR 1
#define HAVE_MKFIFO 1
#define HAVE_MKNOD 1
#define HAVE_MKSTEMP 1
#define HAVE_OPENAT 1
#define HAVE_PIPE 1
#define HAVE_POLL 1
#define HAVE_READLINK 1
#define HAVE_READLINKAT 1
#define HAVE_SELECT 1
#define HAVE_STAT 1
#define HAVE_SYMLINK 1
#define HAVE_UNLINKAT 1
#define HAVE_UTIME 1
#define HAVE_UTIMES 1

/* User/group functions */
#define HAVE_GETGRGID_R 1
#define HAVE_GETGRNAM_R 1
#define HAVE_GETPWNAM_R 1
#define HAVE_GETPWUID_R 1
#define HAVE_GETGRGID 1
#define HAVE_GETGRNAM 1
#define HAVE_GETPWNAM 1
#define HAVE_GETPWUID 1
#define HAVE_GETPID 1

/* String/memory functions */
#define HAVE_MEMMOVE 1
#define HAVE_MEMSET 1
#define HAVE_STRCHR 1
#define HAVE_STRDUP 1
#define HAVE_STRERROR 1
#define HAVE_STRERROR_R 1
#define HAVE_STRFTIME 1
#define HAVE_STRRCHR 1
#define HAVE_STRNLEN 1

/* Time functions */
#define HAVE_TIMEGM 1
#define HAVE_LOCALTIME_R 1
#define HAVE_GMTIME_R 1
#define HAVE_CTIME_R 1
#define HAVE_TZSET 1
#define HAVE_NL_LANGINFO 1

/* Wide char functions */
#define HAVE_WCSCPY 1
#define HAVE_WCSLEN 1
#define HAVE_WCSCMP 1
#define HAVE_WCTOMB 1
#define HAVE_WCRTOMB 1
#define HAVE_WMEMCPY 1
#define HAVE_WMEMCMP 1
#define HAVE_WMEMMOVE 1
#define HAVE_MBRTOWC 1

/* Process functions */
#define HAVE_SETENV 1
#define HAVE_UNSETENV 1
#define HAVE_SETLOCALE 1
#define HAVE_SIGACTION 1
#define HAVE_VFORK 1
#define HAVE_VPRINTF 1
#define HAVE_POSIX_SPAWNP 1

/* Apple-specific */
#define HAVE_COPYFILE 1
#define HAVE_STRUCT_STAT_ST_BIRTHTIME 1
#define HAVE_STRUCT_STAT_ST_BIRTHTIMESPEC_TV_NSEC 1
#define HAVE_STRUCT_STAT_ST_BLKSIZE 1
#define HAVE_STRUCT_STAT_ST_FLAGS 1
#define HAVE_STRUCT_STAT_ST_MTIMESPEC_TV_NSEC 1
#define HAVE_STRUCT_TM_TM_GMTOFF 1

/* Extended attributes (macOS) */
#if TARGET_OS_OSX
#define HAVE_SYS_XATTR_H 1
#define HAVE_SYS_ACL_H 1
#define HAVE_CHFLAGS 1
#define HAVE_FCHFLAGS 1
#define HAVE_LCHFLAGS 1
#define HAVE_LCHMOD 1
#define HAVE_LCHOWN 1
#define HAVE_LUTIMES 1
#define HAVE_ACL_CREATE_ENTRY 1
#define HAVE_ACL_GET_LINK_NP 1
#define HAVE_ACL_INIT 1
#define HAVE_ACL_SET_FILE 1
#define HAVE_ACL_SET_FD 1
#define HAVE_ACL_SET_FD_NP 1
#define HAVE_ACL_TYPE_EXTENDED 1
#define HAVE_MEMBERSHIP_H 1
#define HAVE_ARC4RANDOM_BUF 1
#define HAVE_READPASSPHRASE 1
#endif

/* Large file support */
#define _FILE_OFFSET_BITS 64
#define _LARGEFILE_SOURCE 1
#define _LARGE_FILES 1

/* Error numbers */
#define HAVE_EFTYPE 1
#define HAVE_EILSEQ 1

#endif /* CONFIG_H */
