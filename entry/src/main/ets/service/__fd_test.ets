import { fileIo } from '@kit.CoreFileKit';

export function testFd(): void {
  const testFile: fileIo.File = fileIo.openSync(
    '/data/storage/el2/base/haps/entry/files/temp/__test.txt',
    fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY
  );
  const fd: number = testFile.fd;   // ← 验证此行是否编译通过
  fileIo.closeSync(fd);
}