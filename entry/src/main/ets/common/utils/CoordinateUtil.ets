/**
 * 坐标转换：WGS84（GPS/项目路网基准）→ GCJ02（国测局）→ BD09（百度）
 *
 * 百度地图底图使用 BD09 坐标系，项目路网坐标按 WGS84 采集，
 * 叠加覆盖物前必须转换，否则与底图整体偏移约 500~700 m。
 * 公式为公开算法（火星坐标纠偏 + 百度偏移），误差通常 < 2 m。
 */

const PI: number = Math.PI;
const X_PI: number = PI * 3000 / 180;
const A: number = 6378245; // 长半轴
const EE: number = 0.00669342162296594326; // 扁率

function transformLat(x: number, y: number): number {
  let ret: number = -100 + 2 * x + 3 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * Math.sqrt(Math.abs(x));
  ret += (20 * Math.sin(6 * x * PI) + 20 * Math.sin(2 * x * PI)) * 2 / 3;
  ret += (20 * Math.sin(y * PI) + 40 * Math.sin(y / 3 * PI)) * 2 / 3;
  ret += (160 * Math.sin(y / 12 * PI) + 320 * Math.sin(y * PI / 30)) * 2 / 3;
  return ret;
}

function transformLon(x: number, y: number): number {
  let ret: number = 300 + x + 2 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(Math.abs(x));
  ret += (20 * Math.sin(6 * x * PI) + 20 * Math.sin(2 * x * PI)) * 2 / 3;
  ret += (20 * Math.sin(x * PI) + 40 * Math.sin(x / 3 * PI)) * 2 / 3;
  ret += (150 * Math.sin(x / 12 * PI) + 300 * Math.sin(x / 30 * PI)) * 2 / 3;
  return ret;
}

function outOfChina(lon: number, lat: number): boolean {
  return lon < 72.004 || lon > 137.8347 || lat < 0.8293 || lat > 55.8271;
}

/** WGS84 → GCJ02 */
export function wgs84ToGcj02(lon: number, lat: number): number[] {
  if (outOfChina(lon, lat)) {
    return [lon, lat];
  }
  let dLat: number = transformLat(lon - 105, lat - 35);
  let dLon: number = transformLon(lon - 105, lat - 35);
  const radLat: number = lat / 180 * PI;
  let magic: number = Math.sin(radLat);
  magic = 1 - EE * magic * magic;
  const sqrtMagic: number = Math.sqrt(magic);
  dLat = (dLat * 180) / ((A * (1 - EE)) / (magic * sqrtMagic) * PI);
  dLon = (dLon * 180) / (A / sqrtMagic * Math.cos(radLat) * PI);
  return [lon + dLon, lat + dLat];
}

/** GCJ02 → BD09 */
export function gcj02ToBd09(lon: number, lat: number): number[] {
  const z: number = Math.sqrt(lon * lon + lat * lat) + 0.00002 * Math.sin(lat * X_PI);
  const theta: number = Math.atan2(lat, lon) + 0.000003 * Math.cos(lon * X_PI);
  return [z * Math.cos(theta) + 0.0065, z * Math.sin(theta) + 0.006];
}

/** WGS84 → BD09（一次到位） */
export function wgs84ToBd09(lon: number, lat: number): number[] {
  const gcj: number[] = wgs84ToGcj02(lon, lat);
  return gcj02ToBd09(gcj[0], gcj[1]);
}
