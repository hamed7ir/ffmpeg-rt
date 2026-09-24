/*
 * h264probe -- ffmpeg-rt device payload (BATCH-FFMPEG-1 S6, plus ADDENDUM 4 item 3)
 *
 * Built for armv7-pc-windows-msvc. CANNOT be run on the x64 build box.
 *
 * STATUS after TRIP-1 (ADDENDUM 7):
 *   O-9  ANSWERED YES -- av_get_cpu_flags = 0x3f, NEON YES, on Surface 2 / Tegra 4 /
 *        Windows 10 ARM32 build 15035. The dispatcher selects NEON, so the 6,706
 *        NEON instructions in the shipped DLLs are live. Still printed every run:
 *        it must be re-confirmed per device, and Windows RT 8.1 remains untested.
 *   DECODE  failed on TRIP-1 with AVERROR_INVALIDDATA -- that build had muxers but
 *        no demuxers and no parsers. Fixed in configure; this build carries them,
 *        and print_registered() now proves it at runtime.
 *   O-10 OPEN -- does the device expose usable DXVA2 decode GUIDs? Enumeration only
 *        below. A working D3D9 renderer does NOT imply working DXVA2 decode (AD4).
 *
 * ** NEVER compare fps across devices. Tegra 3 (Surface RT) and Tegra 4 (Surface 2)
 *    are different silicon. Label every number with the device it came from.
 *
 * Usage:  h264probe <clip.h264|clip.mp4>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/cpu.h>
#include <libavutil/pixdesc.h>
#include <libavutil/time.h>

/* TRIP-1 returned a bare "-1094995529" that had to be decoded by hand.
   Never again: every failure below prints its symbolic text too. */
static const char *errstr(int err)
{
    static char buf[AV_ERROR_MAX_STRING_SIZE];
    memset(buf, 0, sizeof(buf));
    av_strerror(err, buf, sizeof(buf));
    return buf;
}

/* ADDENDUM 7: TRIP-1 failed because the build had muxers but no demuxers.
   Print what is actually registered, so the next failure is self-diagnosing. */
static void print_registered(void)
{
    void *o = NULL;
    const AVInputFormat *ifmt;
    int n = 0, have_mov = 0, have_mkv = 0;

    printf("== registered demuxers (AD7 gate, runtime) ==\n    ");
    while ((ifmt = av_demuxer_iterate(&o))) {
        if (ifmt->name) {
            if (!strcmp(ifmt->name, "mov,mp4,m4a,3gp,3g2,mj2")) have_mov = 1;
            if (strstr(ifmt->name, "matroska")) have_mkv = 1;
        }
        n++;
    }
    printf("total = %d   mov/mp4 = %s   matroska = %s\n",
           n, have_mov ? "YES" : "NO -- CANNOT READ MP4",
           have_mkv ? "YES" : "NO");

    {
        void *po = NULL;
        const AVCodecParser *p;
        int np = 0, have_h264p = 0;
        while ((p = av_parser_iterate(&po))) {
            int k;
            for (k = 0; k < AV_PARSER_PTS_NB; k++)
                if (p->codec_ids[k] == AV_CODEC_ID_H264) have_h264p = 1;
            np++;
        }
        printf("  parsers registered = %d   h264 parser = %s\n",
               np, have_h264p ? "YES" : "NO");
    }
}

static void print_build_identity(void)
{
    printf("== build identity ==\n");
    printf("  libavcodec  %u.%u.%u\n", LIBAVCODEC_VERSION_MAJOR,
           LIBAVCODEC_VERSION_MINOR, LIBAVCODEC_VERSION_MICRO);
    printf("  libavformat %u.%u.%u\n", LIBAVFORMAT_VERSION_MAJOR,
           LIBAVFORMAT_VERSION_MINOR, LIBAVFORMAT_VERSION_MICRO);
    printf("  libavutil   %u.%u.%u\n", LIBAVUTIL_VERSION_MAJOR,
           LIBAVUTIL_VERSION_MINOR, LIBAVUTIL_VERSION_MICRO);
    printf("  configuration: %s\n", avcodec_configuration());
}

/* Q3: is the NEON we assembled actually selected at runtime? */
static void print_cpu_flags(void)
{
    int f = av_get_cpu_flags();
    printf("== runtime CPU dispatch (av_get_cpu_flags = 0x%08x) ==\n", f);
#ifdef AV_CPU_FLAG_ARMV5TE
    printf("  ARMV5TE : %s\n", (f & AV_CPU_FLAG_ARMV5TE) ? "yes" : "no");
#endif
#ifdef AV_CPU_FLAG_ARMV6
    printf("  ARMV6   : %s\n", (f & AV_CPU_FLAG_ARMV6)   ? "yes" : "no");
#endif
#ifdef AV_CPU_FLAG_ARMV6T2
    printf("  ARMV6T2 : %s\n", (f & AV_CPU_FLAG_ARMV6T2) ? "yes" : "no");
#endif
#ifdef AV_CPU_FLAG_VFP
    printf("  VFP     : %s\n", (f & AV_CPU_FLAG_VFP)     ? "yes" : "no");
#endif
#ifdef AV_CPU_FLAG_VFPV3
    printf("  VFPV3   : %s\n", (f & AV_CPU_FLAG_VFPV3)   ? "yes" : "no");
#endif
#ifdef AV_CPU_FLAG_NEON
    printf("  NEON    : %s   <== THE ONE THAT MATTERS\n",
           (f & AV_CPU_FLAG_NEON) ? "YES" : "NO");
#endif
    printf("  av_cpu_count: %d\n", av_cpu_count());
}

/* Q4: ADDENDUM 4 -- what hwaccels does this decoder actually advertise here? */
static void print_hwaccels(const AVCodec *dec)
{
    int i;
    printf("== hwaccel enumeration (ADDENDUM 4; enumeration only, no hw decode attempted) ==\n");
    printf("  -- device types compiled in --\n");
    {
        enum AVHWDeviceType t = AV_HWDEVICE_TYPE_NONE;
        int n = 0;
        while ((t = av_hwdevice_iterate_types(t)) != AV_HWDEVICE_TYPE_NONE) {
            printf("    %s\n", av_hwdevice_get_type_name(t));
            n++;
        }
        printf("    (device types found = %d)\n", n);
    }
    if (!dec) return;
    printf("  -- hw configs for decoder '%s' --\n", dec->name);
    for (i = 0;; i++) {
        const AVCodecHWConfig *c = avcodec_get_hw_config(dec, i);
        if (!c) { printf("    (hw configs found = %d)\n", i); break; }
        printf("    pix_fmt=%s device_type=%s methods=0x%x\n",
               av_get_pix_fmt_name(c->pix_fmt),
               av_hwdevice_get_type_name(c->device_type),
               c->methods);
    }
}

int main(int argc, char **argv)
{
    AVFormatContext *fmt = NULL;
    AVCodecContext  *ctx = NULL;
    const AVCodec   *dec = NULL;
    AVPacket *pkt = NULL;
    AVFrame  *frm = NULL;
    int stream_idx = -1, ret, i;
    long long frames = 0, t_start, t_first = 0, t_end;
    int w = 0, h = 0;

    print_build_identity();
    print_cpu_flags();
    print_registered();

    if (argc < 2) {
        fprintf(stderr, "\nusage: %s <clip>\n", argv[0]);
        /* still print hwaccels -- useful even with no clip */
        print_hwaccels(avcodec_find_decoder(AV_CODEC_ID_H264));
        return 2;
    }

    if ((ret = avformat_open_input(&fmt, argv[1], NULL, NULL)) < 0) {
        fprintf(stderr, "avformat_open_input failed: %d (%s)\n", ret, errstr(ret));
        if (ret == AVERROR_INVALIDDATA)
            fprintf(stderr, "  -> AVERROR_INVALIDDATA. Look at the demuxer line above:\n"
                            "     if 'mov' is absent, this build cannot READ mp4.\n");
        return 1;
    }
    if ((ret = avformat_find_stream_info(fmt, NULL)) < 0) {
        fprintf(stderr, "avformat_find_stream_info failed: %d (%s)\n", ret, errstr(ret)); return 1;
    }
    for (i = 0; i < (int)fmt->nb_streams; i++)
        if (fmt->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) { stream_idx = i; break; }
    if (stream_idx < 0) { fprintf(stderr, "no video stream\n"); return 1; }

    dec = avcodec_find_decoder(fmt->streams[stream_idx]->codecpar->codec_id);
    if (!dec) { fprintf(stderr, "no decoder\n"); return 1; }
    print_hwaccels(dec);

    ctx = avcodec_alloc_context3(dec);
    if (!ctx) { fprintf(stderr, "alloc ctx failed\n"); return 1; }
    avcodec_parameters_to_context(ctx, fmt->streams[stream_idx]->codecpar);
    ctx->thread_count = 0;                 /* let it pick */
    if ((ret = avcodec_open2(ctx, dec, NULL)) < 0) {
        fprintf(stderr, "avcodec_open2 failed: %d (%s)\n", ret, errstr(ret)); return 1;
    }
    w = ctx->width; h = ctx->height;

    pkt = av_packet_alloc();
    frm = av_frame_alloc();
    if (!pkt || !frm) { fprintf(stderr, "alloc failed\n"); return 1; }

    printf("== decode: %s  %dx%d  codec=%s  threads=%d ==\n",
           argv[1], w, h, dec->name, ctx->thread_count);

    t_start = av_gettime_relative();
    while (av_read_frame(fmt, pkt) >= 0) {
        if (pkt->stream_index == stream_idx) {
            ret = avcodec_send_packet(ctx, pkt);        /* FFmpeg 3.1+ API */
            if (ret < 0 && ret != AVERROR(EAGAIN)) {
                fprintf(stderr, "send_packet: %d (%s)\n", ret, errstr(ret)); break;
            }
            while ((ret = avcodec_receive_frame(ctx, frm)) >= 0) {
                long long now = av_gettime_relative();
                if (!frames) t_first = now;
                frames++;
                if (frames <= 10 || frames % 100 == 0)
                    printf("  frame %-6lld  t=%lld us\n", frames, now - t_start);
                av_frame_unref(frm);
            }
        }
        av_packet_unref(pkt);
    }
    /* flush */
    avcodec_send_packet(ctx, NULL);
    while (avcodec_receive_frame(ctx, frm) >= 0) { frames++; av_frame_unref(frm); }
    t_end = av_gettime_relative();

    printf("== result ==\n");
    printf("  frames decoded : %lld\n", frames);
    printf("  wall time      : %.3f s\n", (double)(t_end - t_start) / 1e6);
    if (frames > 0 && t_end > t_start)
        printf("  decode fps     : %.2f\n", frames / ((double)(t_end - t_start) / 1e6));
    if (frames > 1 && t_end > t_first)
        printf("  fps excl. first: %.2f\n", (frames - 1) / ((double)(t_end - t_first) / 1e6));
    printf("  resolution     : %dx%d\n", w, h);

    av_frame_free(&frm);
    av_packet_free(&pkt);
    avcodec_free_context(&ctx);
    avformat_close_input(&fmt);
    return frames > 0 ? 0 : 1;
}
