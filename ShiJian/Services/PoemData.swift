import SwiftUI

// MARK: - Poems

struct PoemData {
    static let allPoems: [String] = [
        "落霞与孤鹜齐飞，\n秋水共长天一色。",
        "明月松间照，\n清泉石上流。",
        "云想衣裳花想容，\n春风拂槛露华浓。",
        "行到水穷处，\n坐看云起时。",
        "人生若只如初见，\n何事秋风悲画扇。",
        "月上柳梢头，\n人约黄昏后。",
        "星垂平野阔，\n月涌大江流。",
        "海上生明月，\n天涯共此时。",
        "晴空一鹤排云上，\n便引诗情到碧霄。",
        "红豆生南国，\n春来发几枝。",
        "蓦然回首，那人却在，\n灯火阑珊处。",
        "山有木兮木有枝，\n心悦君兮君不知。",
        "昨夜星辰昨夜风，\n画楼西畔桂堂东。",
        "此情可待成追忆？\n只是当时已惘然。",
        "春蚕到死丝方尽，\n蜡炬成灰泪始干。",
        "两情若是久长时，\n又岂在朝朝暮暮。",
        "大漠孤烟直，\n长河落日圆。",
        "竹外桃花三两枝，\n春江水暖鸭先知。",
        "采菊东篱下，\n悠然见南山。",
        "无言独上西楼，月如钩，\n寂寞梧桐深院锁清秋。",
        "剪不断，理还乱，是离愁，\n别是一般滋味在心头。",
        "长风破浪会有时，\n直挂云帆济沧海。",
        "相见时难别亦难，\n东风无力百花残。",
        "曾经沧海难为水，\n除却巫山不是云。",
        "身无彩凤双飞翼，\n心有灵犀一点通。",
        "枯藤老树昏鸦，\n小桥流水人家，\n古道西风瘦马。",
        "醉后不知天在水，\n满船清梦压星河。",
        "无可奈何花落去，\n似曾相识燕归来。",
        "小楼一夜听春雨，\n深巷明朝卖杏花。",
        "庭院深深深几许，\n杨柳堆烟，\n帘幕无重数。",
        "回首向来萧瑟处，\n归去，\n也无风雨也无晴。",
        "春风得意马蹄疾，\n一日看尽长安花。",
        "几处早莺争暖树，\n谁家新燕啄春泥。",
        "东风夜放花千树，\n更吹落，星如雨。",
        "天接云涛连晓雾，\n星河欲转千帆舞。"
    ]

    static func random() -> String {
        allPoems.randomElement() ?? allPoems[0]
    }

    // 名篇预设
    struct PresetItem: Identifiable {
        let id: String
        let title: String
        let text: String
        let direction: TextBlock.TextDirection
        let fontId: String
        let colorHex: String
    }

    static let presets: [PresetItem] = [
        PresetItem(id: "jinjiujiu", title: "将进酒",
                   text: "君不见黄河之水天上来\n奔流到海不复回\n君不见高堂明镜悲白发\n朝如青丝暮成雪",
                   direction: .vertical, fontId: "zhi-mang-xing", colorHex: "#c8a46e"),
        PresetItem(id: "dingfengbo", title: "定风波",
                   text: "莫听穿林打叶声\n何妨吟啸且徐行\n竹杖芒鞋轻胜马\n谁怕\n一蓑烟雨任平生",
                   direction: .vertical, fontId: "ma-shan-zheng", colorHex: "#e8d5a0"),
        PresetItem(id: "shengshengman", title: "声声慢",
                   text: "寻寻觅觅\n冷冷清清\n凄凄惨惨戚戚\n乍暖还寒时候\n最难将息",
                   direction: .vertical, fontId: "zcool-xiaowei", colorHex: "#f5e6c8"),
        PresetItem(id: "yumeiren", title: "虞美人",
                   text: "春花秋月何时了\n往事知多少\n小楼昨夜又东风\n故国不堪回首月明中",
                   direction: .vertical, fontId: "noto-serif-sc", colorHex: "#f0e8c8"),
        PresetItem(id: "queqiaoxian", title: "鹊桥仙",
                   text: "纤云弄巧\n飞星传恨\n银汉迢迢暗度\n金风玉露一相逢\n便胜却人间无数",
                   direction: .vertical, fontId: "long-cang", colorHex: "#f0e8d0"),
        PresetItem(id: "chuntianli", title: "春江花月夜",
                   text: "春江潮水连海平\n海上明月共潮生\n滟滟随波千万里\n何处春江无月明",
                   direction: .vertical, fontId: "lishu", colorHex: "#f0e8c8"),
    ]
}
